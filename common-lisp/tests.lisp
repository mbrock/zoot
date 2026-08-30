(require "asdf")
(pushnew :zoot-statistics *features*)
(asdf:load-asd (merge-pathnames "zoot.asd" *load-truename*))
(asdf:load-system "zoot" :force t)

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

(defun check-indentation (indentation candidate)
  (check indentation
         (rank-indentation (candidate-rank candidate))
         "indentation differs"))

;;; Document kinds are plain data: strings, the newline character, conses,
;;; and small structs for choice, indentation, and memo checkpoints.

(check t (typep (text "x") 'string))
(check t (typep +newline+ 'character))
(check t (typep (concatenate (text "a") (text "b")) 'cons))
(check t (typep (choice (text "a") (text "b")) 'zoot::choice-document))
(check t (typep (nest 2 (cat +newline+ (text "x"))) 'zoot::nest-document))
(check t (typep (align (cat +newline+ (text "x"))) 'zoot::align-document))

;;; Descriptive combinators preserve the distinction between constructing a
;;; multiline document and subsequently offering its one-line form.

(flet ((make-document ()
         (surrounded-by-parentheses
          (aligned-to-current-column
           (possibly-collapsed-to-one-line
            (one-per-line (list (text "alpha") (text "beta"))))))))
  (check "(alpha beta)" (format-document (make-document) (make-f1 20)))
  (check (format nil "(alpha~% beta)")
         (format-document (make-document) (make-f1 7))))

(check "alpha beta gamma"
       (format-document
        (separated-by-spaces (list "alpha" "beta" "gamma"))
        (make-f1 80)))
(check "{}" (format-document (surrounded-by-braces "") (make-f1 80)))
(check "[]" (format-document (surrounded-by-square-brackets "")
                            (make-f1 80)))

(let ((*indentation-width* 4))
  (check (format nil "head~%    body")
         (format-document
          (cat "head" (indented (starting-on-next-line "body")))
          (make-f1 80))))

;;; These cases mirror the semantic tests in src/pretty.zig.

(let* ((inline (cat (text "foo") (text " ") (text "bar")))
       (multiline (cat (text "foo") +newline+ (text "bar")))
       (result (pick (choice inline multiline) (make-f1 10))))
  (check "foo bar" (render (result-candidate result))))

;;; Verbatim blocks keep their own newlines at column zero, so their
;;; content survives surrounding indentation.

(let* ((document (cat (text "ab")
                      (nest 2 (cat +newline+
                                   (verbatim (format nil "x~%y"))
                                   (text " z")))))
       (result (pick document (make-f1 20))))
  (check (format nil "ab~%  x~%y z") (render (result-candidate result))))

;;; Spans carry annotations through layout, flattening included, without
;;; affecting cost. A RENDER-LAYOUT method specialized on both the span
;;; and the output stream interprets them; other streams see through.

(defclass recording-stream (sb-gray:fundamental-character-output-stream)
  ((target :initarg :target :reader recording-target)
   (events :initform '() :accessor recorded-events)))

(defmethod sb-gray:stream-write-char ((stream recording-stream) char)
  (write-char char (recording-target stream)))

(defmethod render-layout ((document span-document)
                          (stream recording-stream) last base)
  (push (list :open (span-document-meta document))
        (recorded-events stream))
  (prog1 (call-next-method)
    (push (list :close (span-document-meta document))
          (recorded-events stream))))

(let* ((body (group (cat (text "b") +newline+ (text "c"))))
       (document (cat (text "a") (span :hot body) (text "d")))
       (candidate (result-candidate (pick document (make-f1 10)))))
  (check "ab cd" (render candidate))
  (let ((events
          (with-output-to-string (target)
            (let ((stream (make-instance 'recording-stream
                                         :target target)))
              (render candidate stream)
              (check '((:open :hot) (:close :hot))
                     (reverse (recorded-events stream)))))))
    (check "ab cd" events "spans should not disturb plain content")))

;;; Memo checkpoints cache per document, so a document can be resolved
;;; repeatedly under the cost configuration it was first picked with.

(let ((document (cat (text "abcdefgh") +newline+ (text "tail"))))
  (check (format-document document (make-f1 10))
         (format-document document (make-f1 10))
         "picking the same document twice should agree"))

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
  (check-indentation 4 candidate)
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
  (check-indentation 4 many-lines)
  (check-rank 26 3 many-lines))

;;; Cost measurement is a dynamically bindable function value. This objective
;;; assigns one point to every nonempty text placement, independent of width.

(let ((*cost-measure*
        (lambda (page-width column length)
          (declare (ignore page-width column))
          (if (plusp length) 1 0))))
  (let ((candidate
          (result-candidate
           (pick (cat (text "one") (text "two")) (make-f2 80)))))
    (check-rank 2 0 candidate)))

;;; Unrestricted frontiers intentionally accept a third Pareto point that
;;; recursive.zig's current two-Duel representation rejects. Completed larger
;;; frontiers are fixed simple vectors, never adjustable construction buffers.

(let* ((wide (text "123456789"))
       (middle (cat +newline+ (text "12345")))
       (narrow (cat +newline+ +newline+ (text "1")))
       (result (pick (choice wide (choice middle narrow)) (make-f1 100))))
  (check 3 (length (result-frontier result)) "frontier should have three points")
  (check 3 (statistics-frontier-maximum (result-statistics result)))
  (check "123456789" (render (result-candidate result))))

(let ((frontier nil)
      (layout (text "point")))
  (dolist (point '((9 0) (5 1) (1 2)))
    (setf frontier
          (zoot::merge-evaluations
           frontier
           (zoot::%candidate layout (first point) (second point) 0 0))))
  (check-true (typep frontier 'simple-vector)
              "three-point frontier should be a simple vector")
  (check nil (array-has-fill-pointer-p frontier)
         "completed frontier should not have a fill pointer"))

;;; Group and alignment smoke tests.

(flet ((make-document ()
         (let ((body (cat (text "a") +newline+ (text "b"))))
           (cat (text "xx") (align (group body))))))
  (check "xxa b" (format-document (make-document) (make-f1 20)))
  (check (format nil "xxa~%  b")
         (format-document (make-document) (make-f1 3))))

;;; OCaml's structural memo weight reaches zero after six constructors, then
;;; resets at the next parent without inserting a wrapper document.

(let ((document (text "x")))
  (dolist (expected '(5 4 3 2 1 0 5))
    (setf document (concatenate document (text "x")))
    (check expected (zoot::memo-weight document)
           "memo weight differs")))

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
