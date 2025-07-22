
-- Funcion encargada de cargar variables del motor o propias previo al inicio del juego
function love.load()
    love.window.setTitle("Defensa Meteorítica")
    love.window.setMode(800, 600)
	loadHighscores()

    -- Variables fisicas
    gravity = 40 -- Aceleración del mundo
    angle = 45 -- Ángulo por defecto para el proyectil
    speed = 600 -- Velocidad por defecto para el proyectil

    -- Variables de niveles
    score = 0
    gameOver = false
    level = 1
    lives = 5
    targetsToFall = 5
    fallenTargets = 0
    win = false
    
    
    -- Efectos visuales
    delayAfterFlashes = 0.5 
    confettiTimer = 0
	showLevelMessage = false           
	levelMessageTimer = 0              
	levelMessageDuration = 2  
	
    maxLevel = 5
    startColor = {0, 0, 0}         -- negro (nivel 1)
    endColor = {0.5, 0.8, 1}       -- celeste claro (nivel 5)

    cars = {
        {x = 0, y = 570, speed = 100, color = {math.random()*0.7+0.3, math.random()*0.7+0.3, math.random()*0.7+0.3}},
        {x = 200, y = 590, speed = 80, color = {math.random()*0.7+0.3, math.random()*0.7+0.3, math.random()*0.7+0.3}},
    }

    flashes = {}
    confetti = {}
    
    -- Efectos sonoros
    fadingSounds = {}
	
    ajusteSoundAngle = love.audio.newSource("/audio/angulo.wav", "static")
    ajusteSoundAngle:setLooping(true)
    ajusteSoundAngle:setVolume(0)
  
    ajusteSoundSpeed = love.audio.newSource("/audio/carga.wav", "static")
    ajusteSoundSpeed:setLooping(true)
    ajusteSoundSpeed:setVolume(0)

    movimientoSound = love.audio.newSource("/audio/mov.wav", "static")
    movimientoSound:setLooping(true)
    movimientoSound:setVolume(0)

    explosionSound = love.audio.newSource("/audio/explosion.wav", "static")

    bgMusic = love.audio.newSource("/audio/pantalla.wav", "stream")
    bgMusic:setLooping(true)
    bgMusic:setVolume(0.4)
    bgMusic:play()

    function applyReverb(sound)
        local echo = sound:clone()
        echo:setVolume(0.5)
        echo:setPitch(0.8)
        return echo
    end

	function fadeOutSound(sound, duration)
    for _, fs in ipairs(fadingSounds) do
        if fs.sound == sound then
            fs.mode = "out"
            fs.fadeTime = duration
            return
        end
    end

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
    for _, fs in ipairs(fadingSounds) do
        if fs.sound == sound then
            fs.mode = "in"
            fs.fadeTime = duration
            fs.targetVolume = targetVolume or 1
            return
        end
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
        local step = dt / fs.fadeTime  -- paso normalizado

        if fs.mode == "out" then
            fs.volume = fs.volume * math.exp(-step * 5)
            if fs.volume <= 0.001 then
                fs.sound:setVolume(0)
                fs.sound:stop()
                table.remove(fadingSounds, i)
            else
                fs.sound:setVolume(fs.volume)
            end

        elseif fs.mode == "in" then
            fs.volume = fs.volume + step * (fs.targetVolume - fs.volume)
            if math.abs(fs.volume - fs.targetVolume) < 0.001 then
                fs.volume = fs.targetVolume
                fs.sound:setVolume(fs.volume)
                table.remove(fadingSounds, i)
            else
                fs.sound:setVolume(fs.volume)
            end
        end
    end
end

function levelColor(c1, c2, t)
    return {
        c1[1] + (c2[1] - c1[1]) * t,
        c1[2] + (c2[2] - c1[2]) * t,
        c1[3] + (c2[3] - c1[3]) * t
    }
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
        vx = 0,
        color = {0.6, 0.6, 0.6}
    }
end

function resetTargets()
    targets = {}
    spawnedThisLevel = 0
    meteorSpawnTimer = 0
    meteorSpawnInterval = math.max(1.5, 6 - level) -- nivel 1: 5s, nivel 2: 4s, ..., mínimo 1.5s
end

-- Función que se encarga de hacer pasar el tiempo
-- Nos permite actualizar los datos segun una variación de tiempo entre frames
-- Ésto permite dibujar luego cada frame con los datos actualizados
function love.update(dt)
    
	for _, car in ipairs(cars) do
        car.x = (car.x + car.speed * dt) % (love.graphics.getWidth() + 50)
    end
if showLevelMessage then
    levelMessageTimer = levelMessageTimer - dt
    if levelMessageTimer <= 0 then
        showLevelMessage = false
    end
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

    -- Manejo de posiciones y choques luego de se lanzó el proyectil
    if projectile.launched then
        projectile.time = projectile.time + dt
        projectile.x = projectile.x0 + projectile.vx0 * projectile.time
        projectile.y = projectile.y0 + projectile.vy0 * projectile.time + 0.5 * gravity * projectile.time^2

        local vx, vy = projectile.vx0, projectile.vy0 + gravity * projectile.time

        local normalizedHeight = math.max(0, math.min(1, (600 - projectile.y) / 600))
        movimientoSound:setPitch(0.5 + normalizedHeight * 1.5)
        if not movimientoSound:isPlaying() then movimientoSound:play() end

        for _, target in ipairs(targets) do
            if not target.hit then -- Chequeo de impacto previo
                local dx, dy = math.abs(projectile.x - target.x), math.abs(projectile.y - target.y) -- Chequeo de impacto proyectil-meteorito
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
                    target.color = {0.8, 0.3, 0.1} -- cambia a naranja/rojo cuando impacta

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
                    -- Sonido en colisión proyectil-meteorito Pitch y volumen proporcional a masa y velocidad
                    local s = explosionSound:clone()
                    s:setVolume(1)
                    -- Calcular magnitud de velocidad de impacto
                    local speedImpact = math.sqrt(vx1^2 + vy1^2)
                    -- Calcular pitch de la explosión
                    local pitchValue = math.max(0.5, math.min(2.0, 1 + (target.mass / 20)))
                    s:setPitch(pitchValue)
                    --Calcular volumen proporcional a masa y velocidad
                    local volumeValue = math.max(0.3, math.min(1.0, (target.mass * speedImpact)/1000))
                    s:setVolume(volumeValue)
                    s:play()

                    local reverbEcho = applyReverb(explosionSound)
                    reverbEcho: setPitch(pitchValue * 0.8)
                    reverbEcho:play()
                    table.insert(fadingSounds, {sound = s, volume = volumeValue, fadeTime = 1, mode = "out"})
                    table.insert(fadingSounds, {sound = reverbEcho, volume = volumeValue * 0.6, fadeTime = 2, mode = "out"})


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

        -- Si cae en la ciudad, se elimina y resta vida
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
		showLevelMessage = true
		levelMessageTimer = levelMessageDuration
        if level > 5 then
            gameOver = true
            win = true
            table.insert(highscores, score)
            table.sort(highscores, function(a, b) return a > b end)
            while #highscores > 5 do table.remove(highscores) end
            saveHighscores()
        else
            targetsToFall = 5 + (level - 1) * 2
            fallenTargets = 0
            resetTargets()
        end
    end
end

-- Manipulacion de efectos visuales
function updateFlashes(dt)
    for i = #flashes, 1, -1 do
        local f = flashes[i]
        f.alpha = f.alpha - dt * 1.5
        f.x = f.x + f.dx * dt * 10
        f.y = f.y + f.dy * dt * 10
        if f.alpha <= 0 then table.remove(flashes, i) end
    end
end

-- Escucha de inputs
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

-- Funcion requqerida para dibujar en pantalla
function love.draw()
    
    local t = (level - 1) / (maxLevel - 1)
    local bg = levelColor(startColor, endColor, t)
    love.graphics.clear(bg[1], bg[2], bg[3])
	
    -- Dibujar autos
    for _, car in ipairs(cars) do
        love.graphics.setColor(car.color)
        love.graphics.rectangle("fill", car.x - 25, car.y - 15, 50, 25)
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.rectangle("fill", car.x - 15, car.y - 15, 30, 10)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", car.x - 15, car.y + 10, 6)
        love.graphics.circle("fill", car.x + 15, car.y + 10, 6)
    end

    -- Dibujar edificios
    for _, b in ipairs(cityBlocks) do
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", b.x, b.y, b.width, b.height)
        love.graphics.setColor(0.9, 0.9, 0.5)
        for wx = b.x + 4, b.x + b.width - 10, 10 do
            for wy = b.y + 4, b.y + b.height - 12, 12 do
                love.graphics.rectangle("fill", wx, wy, 6, 8)
            end
        end
    end

    -- Dibujar trayectoria si no lanzaste y no hay game over
    if not projectile.launched and not gameOver then
        drawTrajectory()
    end

    -- Dibujar cañón
    local baseX, baseY = 50, 520
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", baseX - 30, baseY, 60, 40)
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.rectangle("fill", baseX - 20, baseY - 30, 40, 30)
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.circle("fill", baseX, baseY + 20, 15)

    -- Dibujar proyectil
    love.graphics.setColor(0.8, 0, 0.6)
    if not projectile.launched then
        love.graphics.circle("fill", baseX, baseY - 15, projectile.radius)
    else
        love.graphics.circle("fill", projectile.x, projectile.y, projectile.radius)
    end

    -- Dibujar meteoritos
    for _, target in ipairs(targets) do
        love.graphics.setColor(target.color)
        love.graphics.circle("fill", target.x, target.y, target.radius)
    end

    -- Dibujar flashes
    for _, f in ipairs(flashes) do
        love.graphics.setColor(f.color[1], f.color[2], f.color[3], f.alpha)
        love.graphics.rectangle("fill", f.x, f.y, f.size, f.size)
    end

    -- Dibujar confeti si ganaste
    for _, c in ipairs(confetti) do
        love.graphics.setColor(c.r, c.g, c.b)
        love.graphics.rectangle("fill", c.x, c.y, 4, 4)
    end

    -- UI
    love.graphics.setColor(1,1,1)
    love.graphics.print("Ángulo: " .. math.floor(angle), 10, 10)
    love.graphics.print("Velocidad: " .. math.floor(speed), 10, 30)
    love.graphics.print("Puntaje: " .. score, 10, 50)
    love.graphics.print("Nivel: " .. level, 10, 70)
    love.graphics.print("Vidas: " .. lives, 10, 90)
	if showLevelMessage then
	 love.graphics.printf("¡Nivel " .. level .. "!", 0, 280, 800, "center")
	end
    if gameOver then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print(win and "¡Ganaste!" or "¡Perdiste!", 320, 300)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Top 5", 350, 330)
        for i, s in ipairs(highscores) do
            love.graphics.print(i .. ". " .. s, 350, 350 + i * 20)
        end
    end
end

-- Linea de la trayectoria
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
