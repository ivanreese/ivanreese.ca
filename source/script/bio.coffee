ready ()->
  bioShift = Math.random()
  canvas = document.querySelector "canvas.js-bio"
  return unless canvas? and window.getComputedStyle(canvas).display != "none"
  context = canvas.getContext "2d"
  width = 0
  height = 0
  dpi = 2 # Just do everything at 2x so that we're good for most retina displays (hard to detect)
  
  scrollTop = document.body.scrollTop + document.body.parentNode.scrollTop
  count = Math.random() * 100 |0
  
  # This otherwise useless functions lets us have a forward reference to renderBio
  # Without it, the first call to rAF would fail
  doRender = ()-> renderBio()
  
  requestRender = ()->
    # Don't render if we're scrolling around
    st = document.body.scrollTop + document.body.parentNode.scrollTop
    requestAnimationFrame(doRender) if st == scrollTop
    scrollTop = st
  
  requestRender()
  setInterval requestRender, 150
  
  renderBio = ()->
    t = Math.sin(++count/25)/2 + 0.5

    # Only resize the buffer when the width changes
    # This provides the nicest behaviour for iOS (which resizes on scroll)
    # And the best perf for Firefox (which hates resizing the buffer)
    newWidth = parseInt(canvas.parentNode.offsetWidth) * dpi
    if width != newWidth
      width = canvas.width = newWidth
      height = canvas.height = parseInt(canvas.parentNode.offsetHeight) * dpi
    
    # FLUSH
    context.clearRect(0, 0, width, height)
    
    if measurePerf
      perfStart = performance.now()
    
    nBlobs = width/6
    for i in [0..nBlobs]
      increase = i/nBlobs # get bigger as i increases
      decrease = (1 - increase) # get smaller as i increases
      a = randTable[i % randTableSize]
      d = randTable[a]
      r = randTable[d]
      c = randTable[r]
      l = randTable[c]
      r = r / randTableSize * width / 5
      # start from 200 (blue), shift up to 170 degrees right (orange), + 40 degrees of jitter. Thus, no green.
      c = (c / randTableSize * 50 + (170 * t) + 200) % 360 |0
      l = l / randTableSize * 10 + 70
      x =          Math.cos((a/randTableSize) * TAU)  * Math.pow(d/randTableSize, 1/10) * (r/2 + width/2)  + width/2|0
      y = Math.abs(Math.sin((a/randTableSize) * TAU)) * Math.pow(d/randTableSize, 1/3)  * (r/2 + height/2) + height/2|0
      context.beginPath()
      context.fillStyle = "hsla(#{c}, 33%, #{l}%, .06)"
      context.arc(x, y, r, 0, TAU)
      context.fill()

    if measurePerf
      console.log((performance.now() - perfStart).toPrecision(4) + "  Bio")
