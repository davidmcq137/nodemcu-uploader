(fn ring-buffer [size]
    (var points [])
    (var index 1)
    {:values (fn [this]
		 (var i 0)
		 (fn []
		     (set i (+ i 1))
		     (. points i)))
    :push (fn [this v] 
	      (tset points index v)
	      (set index (+ index 1))
	      (when (< size index)
		(set index 1)))})


(let [buf (ring-buffer 3)]
     (: buf :push 1)
     (print "values {")
     (each [v (: buf :values)]
	   (print v))
     (print "}")

     (: buf :push 2)
     (print "values {")
     (each [v (: buf :values)]
	   (print v))
     (print "}")

     (: buf :push 3)
     (print "values {")
     (each [v (: buf :values)]
	   (print v))
     (print "}")



     (: buf :push 4)
     (print "values {")
     (each [v (: buf :values)]
	   (print v))
     (print "}")

     (: buf :push 5)
     (print "values {")
     (each [v (: buf :values)]
	   (print v))
     (print "}")

     (: buf :push 6)
     (print "values {")
     (each [v (: buf :values)]
	   (print v))
     (print "}")

     )
