(require "asdf")
(asdf:load-asd (merge-pathnames "zoot.asd" *load-truename*))
(asdf:load-system "zoot")

(defpackage #:zoot-tests
  (:use #:cl #:zoot)
  (:shadowing-import-from #:zoot #:concatenate))

(in-package #:zoot-tests)

(defvar *tests* 0)

(defun check (expected actual &optional (description "values differ"))
  (incf *tests*)
  (unless (equal expected actual)
    (error "~A: expected ~S, got ~S" description expected actual)))

(defun check-true (actual &optional (description "expected a true value"))
  (incf *tests*)
  (unless actual (error "~A" description)))

(defun check-rank (overflow height candidate)
  (check overflow (rank-overflow (candidate-rank candidate)) "overflow differs")
  (check height (rank-height (candidate-rank candidate)) "height differs"))

;;; These cases mirror the semantic tests in src/pretty.zig.

(let* ((inline (cat (text "foo") (text " ") (text "bar")))
       (multiline (cat (text "foo") +newline+ (text "bar")))
       (result (pick (choice inline multiline) (make-f1 10))))
  (check "foo bar" (render (result-candidate result))))

(let* ((cheap-long (text "12345"))
       (costly-short (cat +newline+ (text "x")))
       (tradeoff (choice cheap-long costly-short))
       (document (cat (text "a") tradeoff (text "ZZZZZZ")))
       (candidate (result-candidate (pick document (make-f1 6)))))
  (check (format nil "a~%xZZZZZZ") (render candidate))
  (check-rank 1 1 candidate))

(let* ((tail (cat +newline+ (text "12345") +newline+ (text "b")))
       (document (nest 2 (cat (text "a") tail)))
       (candidate (result-candidate (pick document (make-f1 6)))))
  (check (format nil "a~%  12345~%  b") (render candidate))
  (check 3 (candidate-last candidate))
  (check-rank 1 2 candidate))

(let* ((branch-a (cat (text "a") +newline+ (text "b")))
       (branch-b (cat (text "c") +newline+ (text "d")))
       (candidate (result-candidate
                   (pick (nest 3 (choice branch-a branch-b)) (make-f1 6)))))
  (check (format nil "a~%   b") (render candidate))
  (check 4 (candidate-last candidate)))

;;; Example 3.5 / Figure 7 from A Pretty Expressive Printer.

(let* ((cost (make-f2 6))
       (one-line (result-candidate
                  (pick (text "   = func( pretty, print )") cost)))
       (multiline
         (cat
          (nest 2
                (cat (text "   = func(") +newline+
                     (text "pretty,") +newline+ (text "print")))
          +newline+ (text ")")))
       (many-lines (result-candidate (pick multiline cost))))
  (check-rank 400 0 one-line)
  (check (format nil "   = func(~%  pretty,~%  print~%)")
         (render many-lines))
  (check-rank 26 3 many-lines))

;;; The unrestricted vector representation intentionally accepts a frontier
;;; that recursive.zig's current two-Duel representation rejects.

(let* ((wide (text "123456789"))
       (middle (cat +newline+ (text "12345")))
       (narrow (cat +newline+ +newline+ (text "1")))
       (result (pick (choice wide (choice middle narrow)) (make-f1 100))))
  (check 3 (length (result-frontier result)) "frontier should have three points")
  (check 3 (statistics-frontier-maximum (result-statistics result)))
  (check "123456789" (render (result-candidate result))))

;;; Group and alignment smoke tests.

(let* ((body (cat (text "a") +newline+ (text "b")))
       (document (cat (text "xx") (align (group body)))))
  (check "xxa b" (format-document document (make-f1 20)))
  (check (format nil "xxa~%  b")
         (format-document document (make-f1 3))))

;;; Computation-width taint / Cope behavior, corresponding to the regression
;;; tests in src/pretty.zig.

(let* ((result (pick (text "abcdefgh")
                     (make-f1 4 :computation-width 4)))
       (candidate (result-candidate result))
       (statistics (result-statistics result)))
  (check "abcdefgh" (render candidate))
  (check-rank 4 0 candidate)
  (check t (result-tainted-p result))
  (check 1 (statistics-taints-deferred statistics))
  (check 1 (statistics-taints-forced statistics)))

(let* ((document (cat (text "abc") (text "def")))
       (result (pick document (make-f1 4 :computation-width 4)))
       (statistics (result-statistics result)))
  (check "abcdef" (render (result-candidate result)))
  (check-rank 2 0 (result-candidate result))
  (check t (result-tainted-p result))
  (check-true (>= (statistics-taints-deferred statistics) 2)
              "concatenation should propagate taint")
  (check-true (>= (statistics-taints-forced statistics) 1)))

(let* ((document (choice (text "abcdefgh") (text "ok")))
       (result (pick document (make-f1 4 :computation-width 4)))
       (statistics (result-statistics result)))
  (check "ok" (render (result-candidate result)))
  (check nil (result-tainted-p result))
  (check-true (>= (statistics-taints-deferred statistics) 1))
  (check 0 (statistics-taints-forced statistics)))

(let* ((suffix (choice (text "abcdefgh") (text "ok")))
       (document (cat (text "abcdefgh") +newline+ suffix))
       (result (pick document (make-f1 4 :computation-width 4))))
  (check (format nil "abcdefgh~%ok") (render (result-candidate result)))
  (check t (result-tainted-p result))
  (check-true
   (>= (statistics-taints-forced (result-statistics result)) 1)))

(format t "Common Lisp Zoot: ~D checks passed.~%" *tests*)
