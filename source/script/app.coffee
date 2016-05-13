measurePerf = false

if measurePerf
  console.log "Performance --------------------"

TAU = Math.PI * 2

do ()->

  ## RAND TABLE
  # We use a rand table, rather than Math.random(), so that we can have determinstic randomness.
  # This is not a performance optimization — Math.random() is already VERY fast. It just gives us repeatability.
  
  # Set determinstic to true for debugging, false for deployment
  determinstic = false
  seed = if determinstic then 2147483647 else Math.random() * 2147483647 |0
  
  # Needs to be larger than the number of times we use it in one place, or else we'll get duplication.
  # At this size, it takes about ~2ms to populate the table on my machine
  window.randTableSize = 4096
  
  # This is just a generic swap function. It seems faster to let the browser JIT this than to inline it ourselves.
  swap = (i, j, p)->
    tmp = p[i]
    p[i] = p[j]
    p[j] = tmp
  
  if measurePerf
    perfStart = performance.now()
  
  window.randTable = [0...randTableSize]
  j = 0
  for i in [0...randTableSize]
    j = (j + seed + randTable[i]) % randTableSize
    swap(i, j, randTable)
  
  if measurePerf
    console.log((performance.now() - perfStart).toPrecision(4) + "  Table")