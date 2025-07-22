
function fadeOutSound(sound, duration)
    table.insert(fadingSounds, {
        sound = sound,
        volume = sound:getVolume(),
        fadeTime = duration,
        mode = "out"
    })
end

function fadeInSound(sound, duration, targetVolume)
    if not sound:isPlaying() then
        sound:setVolume(0)
        sound:play()
    end
    table.insert(fadingSounds, {
        sound = sound,
        volume = sound:getVolume(),
        fadeTime = duration,
        targetVolume = targetVolume or 1,
        mode = "in"
    })
end

function updateFadingSounds(dt)
    for i = #fadingSounds, 1, -1 do
        local fs = fadingSounds[i]
        if fs.mode == "out" then
            fs.volume = fs.volume - (dt / fs.fadeTime)
            if fs.volume <= 0 then
                fs.sound:stop()
                table.remove(fadingSounds, i)
            else
                fs.sound:setVolume(fs.volume)
            end
        elseif fs.mode == "in" then
            fs.volume = fs.volume + (dt / fs.fadeTime) * (fs.targetVolume - fs.volume)
            if fs.volume >= fs.targetVolume - 0.01 then
                fs.sound:setVolume(fs.targetVolume)
                table.remove(fadingSounds, i)
            else
                fs.sound:setVolume(fs.volume)
            end
        end
    end
end

function love.load()
    love.window.setTitle("Defensa Meteorítica")
    love.window.setMode(800, 600)
	loadHighscores()

    gravity = 40
    angle = 45
    speed = 600

    score = 0
    gameOver = false

    -- codigo niveles
    delayAfterFlashes = 0.5 -- segundos de espera entre fin de destellos e inicio confeti
    confettiTimer = 0
    level = 1
    lives = 5
    targetsToFall = 5
    fallenTargets = 0
    win = false

    cars = {
        {x=0, y=570, speed=100},
        {x=200, y=590, speed=80},
    }

    flashes = {}
    confetti = {}
    fadingSounds = {}

    ajusteSoundAngle = love.audio.newSource("angulo.wav", "static")
    ajusteSoundAngle:setLooping(true)
    ajusteSoundAngle:setVolume(0)
  
    ajusteSoundSpeed = love.audio.newSource("carga2.wav", "static")
    ajusteSoundSpeed:setLooping(true)
    ajusteSoundSpeed:setVolume(0)

    movimientoSound = love.audio.newSource("carga.wav", "static")
    movimientoSound:setLooping(true)
    movimientoSound:setVolume(0)

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

    meteorSpawnTimer = 0
    meteorSpawnInterval = 5 -- segundos, se reducirá con el nivel
    spawnedThisLevel = 0

    resetProjectile()
    resetTargets()
end

function resetProjectile()
    if movimientoSound:isPlaying() then
        fadeOutSound(movimientoSound, 0.5) -- Fade out 
    end
    projectile = {x0 = 50, y0 = 500, vx0 = 0, vy0 = 0, time = 0, radius = 10, launched = false, x = 50, y = 500, mass = 1}
end

function spawnTarget(xPos)
    local r = 10 + math.random() * 20
    local initialY = -math.random(50, 150)
    local initialX = xPos or math.random(100, 700)
    return {
        x = initialX,
        x0 = initialX,
        vx0 = 0,
        y = initialY,      
        y0 = initialY,     
        vy0 = 0,           
        time = 0,          
        radius = r,
        vy = 0,
        hit = false,
        mass = r / 10,
        vx = 0
    }
end

function resetTargets()
    targets = {}
    spawnedThisLevel = 0
    meteorSpawnTimer = 0
    meteorSpawnInterval = math.max(1.5, 6 - level) -- nivel 1: 5s, nivel 2: 4s, ..., mínimo 1.5s
end

function love.update(dt)
    for _, car in ipairs(cars) do
        car.x = (car.x + car.speed * dt) % (love.graphics.getWidth() + 50)
    end

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

    local adjustingAngle = false
    local adjustingSpeed = false
    if not projectile.launched then
        if love.keyboard.isDown("up") then
            angle = math.min(angle + 60 * dt, 90)
            adjustingAngle = true
        end
        if love.keyboard.isDown("down") then
            angle = math.max(angle - 60 * dt, 0)
            adjustingAngle = true
        end
        if love.keyboard.isDown("right") then
            speed = speed + 150 * dt
            adjustingSpeed = true
        end
        if love.keyboard.isDown("left") then
            speed = math.max(speed - 150 * dt, 0)
            adjustingSpeed = true
        end

        -- Sonido para ángulo
        if adjustingAngle then
            fadeInSound(ajusteSoundAngle, 0.3, 1)
            local jitter = (math.random() - 0.5) * 0.05
            ajusteSoundAngle:setPitch(0.5 + (angle / 90) * 1.5 + jitter) -- 2 octavas
        else
            if ajusteSoundAngle:isPlaying() then fadeOutSound(ajusteSoundAngle, 0.3) end
        end

        -- Sonido para velocidad
        if adjustingSpeed then
            fadeInSound(ajusteSoundSpeed, 0.3, 1)
            local jitter = (math.random() - 0.5) * 0.05
            ajusteSoundSpeed:setPitch(0.5 + (speed / 600) * 1.5 + jitter) -- Normalizado por rango estimado
        else
            if ajusteSoundSpeed:isPlaying() then fadeOutSound(ajusteSoundSpeed, 0.3) end
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
                    -- Cantidad de movimiento
                    local m1 = projectile.mass
                    local m2 = target.mass
                    
                    local vx1 = projectile.vx0
                    local vy1 = projectile.vy0 + gravity * projectile.time
                    
                    local vx2 = target.vx0
                    local vy2 = target.vy0 + gravity * target.time
                    
                    local totalMass = m1 + m2
                    
                    target.vx = (m1 * vx1 + m2 * vx2) / totalMass
                    target.vy = (m1 * vy1 + m2 * vy2) / totalMass

                    target.vx0 = target.vx
                    target.vy0 = target.vy
                    target.x0 = target.x
                    target.y0 = target.y
                    target.time = 0
                    target.mass = totalMass
                    target.radius = target.radius + projectile.radius * 0.5
					target.hit = true

                    score = score + 1

                    local speedImpact = math.sqrt(vx1^2 + vy1^2)
                    for i = 1, 8 do
                        local angle = math.rad(math.random(0, 360))
                        local radius = speedImpact * 0.05 + math.random() * 5
                        table.insert(flashes, {
                            x = projectile.x,
                            y = projectile.y,
                            alpha = 1,
                            size = 2 + math.random() * 4,
                            dx = math.cos(angle) * radius,
                            dy = math.sin(angle) * radius,
                            color = {1, 1, 0}
                        })
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

        if projectile.y > 600 or projectile.x < 0 or projectile.x > 800 then
            resetProjectile()
        end
    end

    updateFlashes(dt)

    for i = #targets, 1, -1 do
        local target = targets[i]

        -- Movimiento de meteoritos
        target.time = target.time + dt
        target.y = target.y0 + target.vy0 * target.time + 0.5 * gravity * target.time^2
        target.x = target.x0 + target.vx0 * target.time

        -- Si cae en la ciudad, lo elimino y resto vida
        if target.y >= 580 then
            lives = lives - 1
            score = math.max(0, score - 1)
            table.remove(targets, i)
            fallenTargets = fallenTargets + 1

            if lives <= 0 then
                gameOver = true
                win = false
                table.insert(highscores, score)
                table.sort(highscores, function(a, b) return a > b end)
                while #highscores > 5 do table.remove(highscores) end
                saveHighscores()
            end
        end
    end
    -- Eliminar meteoritos que se fueron fuera de pantalla
    for i = #targets, 1, -1 do
        if targets[i].y > 600 or targets[i].x > 800 or targets[i].x < 0 or targets[i].y < -200 then
            table.remove(targets, i)
            fallenTargets = fallenTargets + 1
        end
    end

    -- Contar meteoritos activos
    local activeTargets = 0
    for _, t in ipairs(targets) do
        if t.y <= 600 then
            activeTargets = activeTargets + 1
        end
    end

    -- Spawnear meteoritos uno a uno según el intervalo
    if spawnedThisLevel < targetsToFall then
        meteorSpawnTimer = meteorSpawnTimer + dt
        if meteorSpawnTimer >= meteorSpawnInterval then
            meteorSpawnTimer = 0
            local xPos = math.random(100, 700)
            table.insert(targets, spawnTarget(xPos))
            spawnedThisLevel = spawnedThisLevel + 1
        end
    end

    -- Solo subir de nivel si no hay activos y ya cayeron todos los que debían caer
    if fallenTargets >= targetsToFall and activeTargets == 0 then
        level = level + 1
        if level > 5 then
            gameOver = true
            win = true
            table.insert(highscores, score)
            table.sort(highscores, function(a, b) return a > b end)
            while #highscores > 5 do table.remove(highscores) end
            saveHighscores()
        else
            targetsToFall = level * 5
            fallenTargets = 0
            resetTargets()
        end
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


function love.keypressed(key)
    if key == "space" and not projectile.launched and not gameOver then
        local rad = math.rad(angle)
        projectile.vx0 = speed * math.cos(rad)
        projectile.vy0 = -speed * math.sin(rad)
        projectile.launched = true
        projectile.time = 0
        projectile.x0 = projectile.x 
	    projectile.y0 = projectile.y
	-- Activar sonido de movimiento al lanzar
   	if movimientoSound:isPlaying() then movimientoSound:stop() end
	fadeInSound(movimientoSound, 0.3, 1)
    elseif key == "r" then
        score = 0 lives=5 level=1 targetsToFall=5 fallenTargets=0 gameOver = false confetti = {} flashes = {}
        resetProjectile() resetTargets()
    end
end



function love.draw()
    for _, car in ipairs(cars) do
        love.graphics.setColor(0.8,0,0)
        love.graphics.rectangle("fill", car.x-25, car.y-10, 50, 20)
    end
	love.graphics.setColor(1, 1, 1)
    love.graphics.print("Ángulo: " .. math.floor(angle), 10, 10)
    love.graphics.print("Velocidad: " .. math.floor(speed), 10, 30)
    love.graphics.print("Puntaje: " .. score, 10, 50)
	love.graphics.print("Nivel: " .. level, 10, 70)
    love.graphics.print("Vidas: " .. lives, 10, 90)
    if gameOver then
    love.graphics.setColor(1, 1, 0)
    if win then
        love.graphics.print("¡Ganaste el juego!", 300, 300)
    else
        love.graphics.print("¡Perdiste!", 300, 300)
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Top 5", 300, 330)
    for i, s in ipairs(highscores) do
        love.graphics.print(i .. ". " .. s, 300, 350 + i * 20)
    end
end
for _, b in ipairs(cityBlocks) do
    -- Color base del edificio
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", b.x, b.y, b.width, b.height)

    -- Parámetros de las ventanas
    local winW, winH = 6, 8
    local padX, padY = 4, 4

    -- Color de las ventanas (amarillo claro)
    love.graphics.setColor(0.9, 0.9, 0.5)
    for wx = b.x + padX, b.x + b.width - padX - winW, winW + padY do
        for wy = b.y + padY, b.y + b.height - padY - winH, winH + padY do
            love.graphics.rectangle("fill", wx, wy, winW, winH)
        end
    end
end
    for _, f in ipairs(flashes) do
        love.graphics.setColor(f.color[1], f.color[2], f.color[3], f.alpha)
        love.graphics.rectangle("fill", f.x, f.y, f.size, f.size)
    end

    love.graphics.setColor(1, 0.4, 0) if not gameOver then love.graphics.circle("fill", projectile.x, projectile.y, projectile.radius) end

    for _, target in ipairs(targets) do if  not gameOver then love.graphics.setColor(0.6, 0.6, 0.6) love.graphics.circle("fill", target.x, target.y, target.radius) end end

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


function saveHighscores()
    local data = table.concat(highscores, "\n")
    love.filesystem.write("ranking.txt", data)
end

function loadHighscores()
    highscores = {}
    if love.filesystem.getInfo("ranking.txt") then
        local contents = love.filesystem.read("ranking.txt")
        for line in contents:gmatch("[^\r\n]+") do
            table.insert(highscores, tonumber(line))
        end
    end
end

function spawnConfetti() for i = 1, 100 do table.insert(confetti, {x = math.random(0, 800), y = math.random(-100, 0), r = math.random(), g = math.random(), b = math.random(), vy = 50 + math.random() * 100}) end end
function updateConfetti(dt) for _, c in ipairs(confetti) do c.y = c.y + c.vy * dt end end
