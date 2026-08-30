;;; Usage: sbcl --script format-file.lisp FILE [WIDTH]
;;; Pretty-prints a Lisp source file to standard output.

(require "asdf")
(setf *features* (remove :zoot-statistics *features*))
;; Eclector comes from the Nix dev shell's SBCL package registry when
;; available, and from Quicklisp otherwise.
(handler-case (asdf:load-system "eclector")
  (error ()
    (load (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))
    (asdf:load-system "eclector")))
(asdf:load-asd (merge-pathnames "zoot.asd" *load-truename*))
(asdf:load-system "zoot/sexp")

(let* ((arguments (rest sb-ext:*posix-argv*))
       (style (when (member "--ansi" arguments :test #'string=) :ansi))
       (arguments (remove "--ansi" arguments :test #'string=))
       (path (first arguments))
       (width (if (second arguments)
                  (parse-integer (second arguments))
                  80)))
  (unless path
    (format *error-output* "usage: format-file.lisp FILE [WIDTH] [--ansi]~%")
    (sb-ext:exit :code 1))
  (write-string (zoot-sexp:format-file path :width width :style style)))
