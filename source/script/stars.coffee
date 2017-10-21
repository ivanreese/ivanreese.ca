ready ()->
  
  ## BEGIN RAND TABLE
  # We use a rand table, rather than Math.random(), so that we can have determinstic randomness.
  # This is not a performance optimization — Math.random() is already VERY fast. It just gives us repeatability.
  
  # Set determinstic to true for debugging, false for deployment
  determinstic = false
  seed = if determinstic then 2147483647 else Math.random() * 2147483647 |0
  
  # Needs to be larger than the number of times we use it in one place, or else we'll get duplication.
  # At this size, it takes about ~2ms to populate the table on my machine
  randTableSize = 4096
  
  # This is just a generic swap function. It seems faster to let the browser JIT this than to inline it ourselves.
  swap = (i, j, p)->
    tmp = p[i]
    p[i] = p[j]
    p[j] = tmp
  
  randTable = [0...randTableSize]
  j = 0
  for i in [0...randTableSize]
    j = (j + seed + randTable[i]) % randTableSize
    swap i, j, randTable
  ## END RAND TABLE
  
  # Check the DOM to see which mode we'll be running in
  isInfinite = document.getElementById "starfailed-full"
  bw = if document.querySelector "[js-stars-bw]" then 0 else 1
  hud = document.querySelector "hud" if window.location.port is "3000"
  
  for canvas in document.querySelectorAll "canvas.js-stars"
    if window.getComputedStyle(canvas).display != "none"
      do (canvas)->
        context = canvas.getContext "2d"
        dpi = Math.max 1, Math.round(window.devicePixelRatio)
        width = 0
        height = 0
        density = 0
        accel = 0
        vel = 0
        maxVel = defaultMaxVel = 0.05 # Measured in screen-heights
        pos = 0
        renderRequested = false
        first = true
        lastTouchY = 0
        keyboardUp = false
        keyboardDown = false
        keyboardAccel = 0.5
        scrollPos = dpi * (document.body.scrollTop + document.body.parentNode.scrollTop - canvas.offsetTop)
        lastTime = 0
        minFPS = 2
        smoothedFPS = 60
        smoothFPSAdaptationRate = 1/100 # The closer this gets to 1, the more sputtering we get
        alpha = 1
        
        # This is for the css
        canvas.setAttribute "bw", "" if bw is 0
        
        resize = ()->
          width  = canvas.width = canvas.parentNode.offsetWidth * dpi
          height = canvas.height = canvas.parentNode.offsetHeight * dpi
          density = scale Math.sqrt(width * height)/dpi, 0, 1500, 0, 1 # Scale the number of objects based on the canvas size
          maxVel = defaultMaxVel * window.innerHeight # Scale the velocity based on the height of the screen
          context.lineCap = "round"
          first = true
        
        doRender = (time)->
          renderRequested = false
          renderStars time, normalDrawCall
        
        requestRender = ()->
          unless renderRequested
            renderRequested = true
            requestAnimationFrame doRender
        
        requestScrollRender = (e)->
          p = dpi * (document.body.scrollTop + document.body.parentNode.scrollTop - canvas.offsetTop)
          delta = p - scrollPos
          scrollPos = p
          vel += delta / 20
          requestRender()
        
        requestWheelRender = (e)->
          vel -= e.deltaY / 20
          requestRender()

        requestMoveRender = (e)->
          e.preventDefault() if isInfinite
          y = e.touches.item(0).screenY
          vel -= (y - lastTouchY) / 15
          lastTouchY = y
          requestRender()
        
        touchStart = (e)->
          e.preventDefault() if isInfinite
          lastTouchY = e.touches.item(0).screenY
          
        keyDown = (e)->
          keyboardUp = true if e.keyCode == 38
          keyboardDown = true if e.keyCode == 40
          requestRender()
        
        keyUp = (e)->
          keyboardUp = false if e.keyCode == 38
          keyboardDown = false if e.keyCode == 40
          requestRender()
        
        requestResize = ()->
          if width isnt canvas.parentNode.offsetWidth * dpi
            requestAnimationFrame (time)->
              first = true
              resize()
              renderStars time, firstDrawCall
        
        requestResize()
        window.addEventListener "resize", requestResize
        if isInfinite
          window.addEventListener "wheel", requestWheelRender
        else
          window.addEventListener "scroll", requestScrollRender, passive: true
        window.addEventListener "touchstart", touchStart, passive: !isInfinite
        window.addEventListener "touchmove", requestMoveRender, passive: !isInfinite
        window.addEventListener "keydown", keyDown
        window.addEventListener "keyup", keyUp
        
        
        firstDrawCall = (x, y, r, s)->
          context.beginPath()
          context.fillStyle = s
          context.arc x, y, r, 0, TAU
          context.fill()
        
        normalDrawCall = (x, y, r, s, velScale)->
          context.beginPath()
          context.strokeStyle = s
          context.lineWidth = r*2
          context.moveTo x, y - (vel*dpi*velScale)
          context.lineTo x, y
          context.stroke()
        
        renderStars = (time, drawCall)->
          # Limit the dt range to avoid divide by zero errors, major weirdness from long pauses, etc
          dt = clip time - lastTime, 1, 100
          fps = 1000/dt
          lastTime = time
          smoothedFPS = smoothedFPS*(1-smoothFPSAdaptationRate) + fps*smoothFPSAdaptationRate
          
          # If we aren't moving (eg: the initial render), render at full quality
          frameRateLOD = if vel is 0
            1
          else # The scene is moving, so adjust the LOD based on the frame rate
            # It's not worth hitting 60fps if that means rendering nothing.
            # This config reaches an equalibrium around 35 FPS in Safari on my Mac.
            scale smoothedFPS, 20, 60, 0.3, 1, true
            # 1
          
          return unless scrollPos < Math.max(height, 1000) and !document.hidden
          
          if keyboardDown and not keyboardUp
            accel = +keyboardAccel
          else if keyboardUp and not keyboardDown
            accel = -keyboardAccel
          else
            accel /= 1.05
          
          vel += accel
          vel /= 1.05 unless isInfinite and Math.abs(vel) < 0.5
          vel = Math.min maxVel, Math.max -maxVel, vel
          pos -= vel * dpi
          
          if Math.abs(vel) > 0.1
            requestRender()
          
          if not first
            targetAlpha = Math.min 1, Math.sqrt Math.abs vel/maxVel
            alpha += clip targetAlpha - alpha, -0.05, 0.05
          
          if first
            maxPixelStars = 800
            maxStars = 100
            maxSmallGlowingStars = 50
            maxPurpBlobs = 200
            maxBlueBlobs = 300
            maxRedBlobs = 300
          else
            maxPixelStars = 350
            maxStars = 35
            maxSmallGlowingStars = 35
            maxPurpBlobs = 100
            maxBlueBlobs = 120
            maxRedBlobs = 120
          
          nPixelStars        = density * frameRateLOD * maxPixelStars |0
          nStars             = density * frameRateLOD * maxStars |0
          nSmallGlowingStars = density * frameRateLOD * maxSmallGlowingStars |0
          nPurpBlobs         = density * frameRateLOD * maxPurpBlobs |0
          nBlueBlobs         = density * frameRateLOD * maxBlueBlobs |0
          nRedBlobs          = density * frameRateLOD * maxRedBlobs |0
          
          if hud?
            hud.textContent = smoothedFPS.toPrecision(3)
          
          
          # Pixel Stars
          i = 0
          while i < maxPixelStars
            increase = i/maxPixelStars
            x = randTable[(i + 5432) % randTableSize]
            y = randTable[x]
            o = randTable[y]
            r = randTable[o]
            x = x * width / randTableSize
            y = mod y * height / randTableSize - pos * increase, height
            o = o / randTableSize * 0.99 + 0.01
            r = r / randTableSize * 1.5 + .5
            drawCall x, y, r * dpi/2, "hsla(300, #{25*bw}%, 50%, #{o*alpha})", increase
            i++
            
          
          # Stars
          i = 0
          while i < nStars
            increase = i/maxStars
            decrease = 1 - increase
            x = randTable[i % randTableSize]
            y = randTable[x]
            r1 = randTable[y]
            r2 = randTable[r1]
            sx = randTable[r2]
            sy = randTable[sx]
            l = randTable[sy]
            c = randTable[l]
            o = randTable[c]
            x = x * width / randTableSize
            y = mod y * height / randTableSize - pos * decrease, height
            r1 = r1 / randTableSize * 4 + .5
            r2 = r2 / randTableSize * 3 + .5
            l = l / randTableSize * 20 + 80
            o = o / randTableSize * 10 * decrease + 0.3
            c = c / randTableSize * 120 + 200
            drawCall x, y, r1 * dpi/2, "hsla(#{c}, #{30*bw}%, #{l}%, #{o*alpha})", decrease
            drawCall x, y, r2 * dpi/2, "hsla(0, 0%, 100%, 1)", decrease
            i++

          
          # Small Round Stars with circular glow rings
          i = 0
          while i < nSmallGlowingStars
            increase = i/maxSmallGlowingStars
            decrease = 1 - increase
            r = randTable[(i + 345) % randTableSize]
            l = randTable[r]
            o = randTable[l]
            c = randTable[o]
            x = randTable[c]
            y = randTable[x]
            x = x * width / randTableSize
            y = mod y * height / randTableSize - pos * decrease, height
            r = r / randTableSize * 2 + 1
            l = l / randTableSize * 20 + 60
            o = o / randTableSize * 1 * decrease + 0.3
            c = c / randTableSize * 180 + 200
            
            # far ring
            drawCall x, y, r * r * r * dpi/2, "hsla(#{c}, #{70*bw}%, #{l}%, #{o/25*alpha})", decrease
            
            # close ring
            drawCall x, y, r * r * dpi/2, "hsla(#{c}, #{50*bw}%, #{l}%, #{o/6*alpha})", decrease
            
            # round star body
            drawCall x, y, r * dpi/2, "hsla(#{c}, #{20*bw}%, #{l}%, #{o*alpha})", decrease
            
            # point of light
            drawCall x, y, 1 * dpi/2, "hsla(#{c}, #{100*bw}%, 90%, #{o * 1.5*alpha})", decrease
            
            i++

          
          # Alpha for blobs
          if first
            alpha = 0.6
          else
            alpha = Math.sqrt Math.abs vel/8
          
          
          # Purple Blobs
          i = 0
          while i < nPurpBlobs
            increase = i/maxPurpBlobs
            decrease = 1 - increase
            x = randTable[(i + 1234) % randTableSize]
            y = randTable[x]
            _r = randTable[y]
            l = randTable[_r]
            o = randTable[l]
            x = x / randTableSize * width*2/3 + width*1/6
            r = _r / randTableSize * 300 * density * decrease + 20
            velScale = (1 - 0.99 * _r/randTableSize) * decrease
            y = mod(y / randTableSize * height*2/3 + height*1/6 - pos * velScale, height+r*2)-r
            l = l / randTableSize * 15 * increase
            o = o / randTableSize * 0.07 + 0.05
            drawCall x, y, r * dpi/2, "hsla(290, #{100*bw}%, #{l}%, #{o*alpha})", velScale
            i++
          
          
          if not first
            alpha = alpha * 2 - 1
          
          
          # Blue Blobs
          i = 0
          while i < nBlueBlobs
            increase = i/maxBlueBlobs
            decrease = 1 - increase
            x = randTable[(i + 123) % randTableSize]
            y = randTable[x]
            r = randTable[y]
            l = randTable[r]
            s = randTable[l]
            h = randTable[s]
            o = randTable[h]
            x = x / randTableSize * width
            r = r / randTableSize * 130 * density * decrease + 20
            velScale = decrease * 0.2 + 0.5
            y = mod(y / randTableSize * height*2/3 + height*5/6 - pos * velScale, height + r*2)-r
            s = (s / randTableSize * 30 + 70) * bw
            l = l / randTableSize * 64 + 1
            h = h / randTableSize * 50 + 210
            o = o / randTableSize * 0.03 + 0.005
            drawCall x, y, r * 1 * dpi/2, "hsla(#{h}, #{s}%, #{l}%, #{o*alpha})", velScale
            drawCall x, y, r * 2 * dpi/2, "hsla(#{h}, #{s}%, #{l}%, #{o/2*alpha})", velScale
            drawCall x, y, r * 3 * dpi/2, "hsla(#{h}, #{s}%, #{l}%, #{o/4*alpha})", velScale
            i++


          # Red Blobs
          i = 0
          while i < nRedBlobs
            increase = i/maxRedBlobs
            decrease = 1 - increase
            o = randTable[(12345 + i) % randTableSize]
            x = randTable[o]
            y = randTable[x]
            r = randTable[y]
            l = randTable[r]
            h = randTable[l]
            x = x / randTableSize * width
            r = r / randTableSize * 170 * decrease * density + 20
            velScale = increase * 0.8 + 0.2
            y = mod(y / randTableSize * height*2/3 + height*1/2 - pos * velScale, height + r*2)-r
            l = l / randTableSize * 60 + 20
            o = o / randTableSize * 0.03 + 0.005
            h = h / randTableSize * 30 + 345
            s = 100 * bw
            drawCall x, y, r * 1 * dpi/2, "hsla(#{h}, #{s}%, #{l}%, #{o*alpha})", velScale
            drawCall x, y, r * 2 * dpi/2, "hsla(#{h}, #{s}%, #{l}%, #{o/3*alpha})", velScale
            drawCall x, y, r * 3 * dpi/2, "hsla(#{h}, #{s}%, #{l}%, #{o/9*alpha})", velScale
            i++
          
          first = false
  undefined
