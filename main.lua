-- Mejoras:
-- 1. Menos meteoritos en nivel 1.
-- 2. Flechas visuales junto a ángulo y velocidad.
-- 3. Detener meteoritos y cursor al finalizar el nivel.
-- 4. Confeti al terminar el juego.
-- Mejoras 2:
-- 1. Flechas visibles como íconos (usamos Unicode).
-- 2. Sonido de disparo al colisionar con meteorito, con pitch según masa.
-- Mejora: Reverb en sonido de explosión + Fade out
-- Agregar música de fondo y mejorar visual de explosiones con destellos
-- Mejorar animación: completar destellos antes de iniciar confeti

local delayAfterFlashes = 0.5 -- segundos de espera entre fin de destellos e inicio confeti
local confettiTimer = 0

function love.load()
    love.window.setTitle("Defensa Meteorítica")
    love.window.setMode(800, 600)

    gravity = 200
    angle = 45
    speed = 300

    score = 0
    gameOver = false
    destroyedCount = 0

    flashes = {}
    confetti = {}
    fadingSounds = {}

    -- Usamos carga.wav en vez de ajuste.wav
    ajusteSound = love.audio.newSource("carga.wav", "static")
    ajusteSound:setLooping(true)

    movimientoSound = love.audio.newSource("carga.wav", "static")
    movimientoSound:setLooping(true)

    explosionSound = love.audio.newSource("explosion.wav", "static")

    bgMusic = love.audio.newSource("pantalla.wav", "stream")
    bgMusic:setLooping(true)
    bgMusic:setVolume(0.4)
    bgMusic:play()

    function applyReverb(sound)
        local echo = sound:clone()
        echo:setVolume(0.5)
        echo:setPitch(0.8)
        return echo
    end

    cityBlocks = {
        {x = 0, y = 580, width = 800, height = 20},
        {x = 100, y = 560, width = 40, height = 40},
        {x = 200, y = 550, width = 60, height = 50},
        {x = 300, y = 540, width = 50, height = 60},
        {x = 500, y = 550, width = 70, height = 50},
        {x = 650, y = 560, width = 30, height = 40},
    }

    resetProjectile()
    resetTargets()
end

function resetProjectile()
    if movimientoSound:isPlaying() then movimientoSound:stop() end
    projectile = {x0 = 100, y0 = 500, vx0 = 0, vy0 = 0, time = 0, radius = 10, launched = false, x = 100, y = 500, mass = 1}
end

function spawnTarget()
    local r = 10 + math.random() * 20
    return {x = math.random(100, 700), y = -math.random(100, 300), radius = r, vy = 20 + math.random() * 40, hit = false, mass = r / 10, vx = 0}
end

function resetTargets()
    targets = {}
    for i = 1, 3 do table.insert(targets, spawnTarget()) end
end

function love.update(dt)
    if gameOver then
        if #flashes > 0 then
            updateFlashes(dt)
        else
            confettiTimer = confettiTimer + dt
            if confettiTimer >= delayAfterFlashes and #confetti == 0 then
                spawnConfetti()
            end
            updateConfetti(dt)
        end
        updateFadingSounds(dt)
        return
    end

    updateFadingSounds(dt)

    local adjusting = false

    if not projectile.launched then
        if love.keyboard.isDown("right") then speed = speed + 150 * dt adjusting = true end
        if love.keyboard.isDown("left") then speed = math.max(speed - 150 * dt, 0) adjusting = true end
        if love.keyboard.isDown("up") then angle = math.min(angle + 60 * dt, 90) adjusting = true end
        if love.keyboard.isDown("down") then angle = math.max(angle - 60 * dt, 0) adjusting = true end

        if adjusting then
            ajusteSound:setPitch(0.5 + (speed / 400) + (angle / 180))
            if not ajusteSound:isPlaying() then ajusteSound:play() end
        else
            if ajusteSound:isPlaying() then ajusteSound:stop() end
        end
    end

    if projectile.launched then
        projectile.time = projectile.time + dt
        projectile.x = projectile.x0 + projectile.vx0 * projectile.time
        projectile.y = projectile.y0 + projectile.vy0 * projectile.time + 0.5 * gravity * projectile.time^2

        local vx, vy = projectile.vx0, projectile.vy0 + gravity * projectile.time

        local normalizedHeight = math.max(0, math.min(1, (600 - projectile.y) / 600))
        movimientoSound:setPitch(0.5 + normalizedHeight * 1.5)
        if not movimientoSound:isPlaying() then movimientoSound:play() end

        for _, target in ipairs(targets) do
            if not target.hit then
                local dx, dy = math.abs(projectile.x - target.x), math.abs(projectile.y - target.y)
                if dx < (target.radius + projectile.radius) and dy < (target.radius + projectile.radius) then
                    target.hit = true
                    score = score + 1
                    destroyedCount = destroyedCount + 1

                    local speedImpact = math.sqrt(vx^2 + vy^2)
                    for i = 1, 8 do
                        local angle = math.rad(math.random(0, 360))
                        local radius = speedImpact * 0.05 + math.random() * 5
                        table.insert(flashes, {x = projectile.x, y = projectile.y, alpha = 1, size = 2 + math.random() * 4, dx = math.cos(angle) * radius, dy = math.sin(angle) * radius, color = {1, 1, 0}})
                    end

                    local s = explosionSound:clone()
                    s:setVolume(1)
                    s:play()
                    local reverbEcho = applyReverb(explosionSound)
                    reverbEcho:play()
                    table.insert(fadingSounds, {sound = s, volume = 1})
                    table.insert(fadingSounds, {sound = reverbEcho, volume = 0.5})

                    resetProjectile()
                    break
                end
            end
        end

        if projectile.y > 600 then resetProjectile() end
    end

    updateFlashes(dt)

    for i, target in ipairs(targets) do
        if not target.hit then
            target.y = target.y + target.vy * dt
            target.x = target.x + (target.vx or 0) * dt
        elseif target.y > 600 then targets[i] = spawnTarget() end
    end

    if destroyedCount >= 3 then
        gameOver = true
        confettiTimer = 0 -- reinicia el temporizador para confeti
    end
end

function updateFlashes(dt)
    for i = #flashes, 1, -1 do
        local f = flashes[i]
        f.alpha = f.alpha - dt * 1.5
        f.x = f.x + f.dx * dt * 10
        f.y = f.y + f.dy * dt * 10
        if f.alpha <= 0 then table.remove(flashes, i) end
    end
end

function updateFadingSounds(dt)
    for i = #fadingSounds, 1, -1 do
        local fs = fadingSounds[i]
        fs.volume = fs.volume - dt * 0.5
        if fs.volume <= 0 then fs.sound:stop() table.remove(fadingSounds, i) else fs.sound:setVolume(fs.volume) end
    end
end

function love.keypressed(key)
    if key == "space" and not projectile.launched and not gameOver then
        local rad = math.rad(angle)
        projectile.vx0 = speed * math.cos(rad)
        projectile.vy0 = -speed * math.sin(rad)
        projectile.launched = true
        projectile.time = 0
        projectile.x0 = projectile.x projectile.y0 = projectile.y
    elseif key == "r" then
        score = 0 destroyedCount = 0 gameOver = false confetti = {} flashes = {}
        resetProjectile() resetTargets()
    end
end

function love.draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Ángulo: " .. math.floor(angle) .. " ↑↓", 10, 10)
    love.graphics.print("Velocidad: " .. math.floor(speed) .. " ←→", 10, 30)
    love.graphics.print("Puntaje: " .. score, 10, 50)
    if gameOver then love.graphics.setColor(1, 1, 0) love.graphics.print("¡Nivel completado!", 300, 300) end

    for _, b in ipairs(cityBlocks) do love.graphics.setColor(0.5, 0.5, 0.5) love.graphics.rectangle("fill", b.x, b.y, b.width, b.height) end

    for _, f in ipairs(flashes) do
        love.graphics.setColor(f.color[1], f.color[2], f.color[3], f.alpha)
        love.graphics.rectangle("fill", f.x, f.y, f.size, f.size)
    end

    love.graphics.setColor(1, 0.4, 0) if not gameOver then love.graphics.circle("fill", projectile.x, projectile.y, projectile.radius) end

    for _, target in ipairs(targets) do if not target.hit and not gameOver then love.graphics.setColor(0.6, 0.6, 0.6) love.graphics.circle("fill", target.x, target.y, target.radius) end end

    for _, c in ipairs(confetti) do love.graphics.setColor(c.r, c.g, c.b) love.graphics.rectangle("fill", c.x, c.y, 4, 4) end

    if not projectile.launched and not gameOver then drawTrajectory() end
end

function drawTrajectory()
    local rad = math.rad(angle)
    local vx, vy = speed * math.cos(rad), -speed * math.sin(rad)
    local simX, simY, g = projectile.x, projectile.y, gravity
    local points = {}
    for t = 0, 2, 0.1 do table.insert(points, {simX + vx * t, simY + vy * t + 0.5 * g * t * t}) end
    love.graphics.setColor(0, 1, 1)
    for i = 1, #points - 1 do love.graphics.line(points[i][1], points[i][2], points[i + 1][1], points[i + 1][2]) end
end

function spawnConfetti() for i = 1, 100 do table.insert(confetti, {x = math.random(0, 800), y = math.random(-100, 0), r = math.random(), g = math.random(), b = math.random(), vy = 50 + math.random() * 100}) end end
function updateConfetti(dt) for _, c in ipairs(confetti) do c.y = c.y + c.vy * dt end end
