(defpackage #:zoot-benchmark
  (:use #:cl #:zoot)
  (:shadowing-import-from #:zoot #:concatenate))

(in-package #:zoot-benchmark)

(defun join-documents (separator documents)
  (if (null documents)
      (text "")
      (reduce (lambda (left right)
                (cat left separator right))
              (rest documents)
              :initial-value (first documents))))

(defun call-document (items)
  "A token-preserving choice between horizontal and vertical S-expression
layout. Both branches contain exactly the same non-whitespace tokens."
  (let ((horizontal (join-documents (text " ") items))
        (vertical (apply #'vcat items)))
    (cat (text "(")
         (align (choice horizontal vertical))
         (text ")"))))

(defun ternary-document (depth)
  "Construct a fresh full ternary expression tree with choices at each call."
  (let ((ordinal 0))
    (labels ((name (prefix)
               (prog1 (text (format nil "~A~D" prefix ordinal))
                 (incf ordinal)))
             (walk (remaining)
               (let ((operator (name "f")))
                 (if (zerop remaining)
                     (call-document
                      (list operator (name "x") (name "x") (name "x")))
                     (call-document
                      (list operator
                            (walk (1- remaining))
                            (walk (1- remaining))
                            (walk (1- remaining))))))))
      (walk depth))))

(defun shared-document (depth)
  "Construct a DAG: each level concatenates the same child on both branches."
  (labels ((walk (remaining)
             (if (zerop remaining)
                 (choice (text "shared-wide")
                         (cat +newline+ (text "s")))
                 (let ((child (walk (1- remaining))))
                   (choice
                    (cat (text "(") child (text " ") child (text ")"))
                    (cat (text "(") (align (vcat child child)) (text ")")))))))
    (walk depth)))

(defun tainted-document (count)
  "An overflowing prefix followed by fitting alternatives after newlines."
  (apply #'cat
         (loop repeat count
               append (list (text "unavoidably-wide-token")
                            +newline+
                            (choice (text "also-far-too-wide")
                                    (text "ok"))))))

;;; The pretty-printer workload formats a real Lisp source file.

(defparameter *corpus-fallback*
  (merge-pathnames "zoot.lisp" (or *load-truename* *default-pathname-defaults*)))

(defun corpus-path ()
  "The Lisp source file for pretty-printer workloads: ZOOT_LISP_CORPUS,
which the Nix dev shell points at Eclector's largest source file, with
this project's own zoot.lisp as the fallback."
  (or (let ((path (sb-ext:posix-getenv "ZOOT_LISP_CORPUS")))
        (and path (plusp (length path)) (probe-file path)))
      (probe-file *corpus-fallback*)))

(defun read-corpus (path)
  (with-open-file (stream path)
    (let ((source (make-string (file-length stream))))
      (subseq source 0 (read-sequence source stream)))))

(defun load-pretty-printer ()
  "Load zoot/sexp and its Eclector dependency, from the ASDF registry or
Quicklisp; NIL when neither can provide Eclector."
  (handler-case
      (progn
        (handler-case (asdf:load-system "eclector")
          (error ()
            (load (merge-pathnames "quicklisp/setup.lisp"
                                   (user-homedir-pathname)))
            (asdf:load-system "eclector")))
        (asdf:load-system "zoot/sexp")
        t)
    (error () nil)))

(defun format-corpus (source)
  (uiop:symbol-call '#:zoot-sexp '#:format-source source))
