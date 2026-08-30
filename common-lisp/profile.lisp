(require :sb-sprof)
(require "asdf")
(asdf:load-asd (merge-pathnames "zoot.asd" *load-truename*))
(asdf:load-system "zoot")
(load (merge-pathnames "benchmark-workloads.lisp" *load-truename*))

(in-package #:zoot-benchmark)

(defun command-line-integer (index default)
  (let ((argument (nth index sb-ext:*posix-argv*)))
    (if argument
        (or (parse-integer argument :junk-allowed t) default)
        default)))

(let ((samples (command-line-integer 1 1500))
      (depth (command-line-integer 2 4))
      (cost (make-f2 80)))
  (unless (plusp samples)
    (error "SAMPLES must be positive, got ~S" samples))
  (unless (plusp depth)
    (error "DEPTH must be positive, got ~S" depth))
  ;; Warm compilation, caches unrelated to document memoization, and profiler
  ;; machinery before resetting the sample buffer.
  (pick (ternary-document depth) cost)
  (format t "~&Common Lisp Zoot profile: ternary depth ~D, ~D CPU samples~%"
          depth samples)
  (sb-sprof:with-profiling
      (:mode :cpu
       :sample-interval 0.001d0
       :max-samples samples
       :loop t
       :reset t
       :report :flat)
    (pick (ternary-document depth) cost)))
