;;; A pretty-printer for Common Lisp source text, built on Zoot.
;;;
;;; Source is read with Eclector, but without interning: symbols stay
;;; raw source slices, so formatting needs no packages, preserves case
;;; exactly, and keeps comments, feature guards, and blank lines. Each
;;; top-level form becomes a Zoot document offering one-line and broken
;;; layouts at every level, and PICK finds the optimal layout under the
;;; page-width cost.

(defpackage #:zoot-sexp
  (:use #:cl)
  (:import-from #:zoot
                #:verbatim #:+newline+ #:cat #:choice #:nest #:align
                #:span #:span-document #:span-document-meta
                #:render-layout
                #:pick #:render #:result-candidate #:make-f2)
  (:export #:format-source #:format-file #:source-tokens))

(in-package #:zoot-sexp)

;;; Source nodes

(defstruct (raw (:constructor raw (text &optional start end)))
  "An atom of any kind, kept as its raw source text."
  (text "" :type string :read-only t)
  (start 0 :type fixnum :read-only t)
  (end 0 :type fixnum :read-only t))

(defstruct (wrap (:constructor wrap (prefix child start end)))
  "A read-macro prefix such as ', `, ,@, #', or #. applied to one form."
  (prefix "" :type string :read-only t)
  (child nil)
  (start 0 :type fixnum :read-only t)
  (end 0 :type fixnum :read-only t))

(defstruct (guard (:constructor guard (prefix condition form start end)))
  "A #+ or #- feature expression guarding one form."
  (prefix "" :type string :read-only t)
  (condition nil)
  (form nil)
  (start 0 :type fixnum :read-only t)
  (end 0 :type fixnum :read-only t))

(defstruct (paren (:constructor paren (open items start end)))
  "A parenthesized form, or a #( vector."
  (open "(" :type string :read-only t)
  (items nil :type list)
  (start 0 :type fixnum :read-only t)
  (end 0 :type fixnum :read-only t))

(defstruct (remark (:constructor remark (text start end)))
  "A comment. Trailing remarks stay on the previous item's line."
  (text "" :type string :read-only t)
  (trailing-p nil :type boolean)
  (start 0 :type fixnum :read-only t)
  (end 0 :type fixnum :read-only t))

(defstruct (pending (:constructor pending (start end)))
  "A feature guard whose branch this image's features rejected; its
region is re-read after the enclosing read completes."
  (start 0 :type fixnum :read-only t)
  (end 0 :type fixnum :read-only t))

(defstruct (gap (:constructor gap ()))
  "A blank line between items.")

(deftype node ()
  '(or raw wrap guard paren remark pending))

(defun node-start (node)
  (etypecase node
    (raw (raw-start node))
    (wrap (wrap-start node))
    (guard (guard-start node))
    (paren (paren-start node))
    (remark (remark-start node))
    (pending (pending-start node))))

(defun node-end (node)
  (etypecase node
    (raw (raw-end node))
    (wrap (wrap-end node))
    (guard (guard-end node))
    (paren (paren-end node))
    (remark (remark-end node))
    (pending (pending-end node))))

;;; The Eclector client
;;;
;;; Symbols are interpreted as bare name strings and every result node
;;; is built from its source slice, so nothing is interned and nothing
;;; is evaluated. Feature expressions are evaluated by name against
;;; *FEATURES* only so that reading can proceed; a rejected branch
;;; becomes a PENDING node and is re-read afterwards, so both branches
;;; of a guard format identically whatever the features say.

(defclass client (eclector.parse-result:parse-result-client)
  ((text :initarg :text :reader client-text)))

(defmethod eclector.reader:interpret-symbol
    ((client client) input-stream package-indicator symbol-name internp)
  (declare (ignore input-stream package-indicator internp))
  symbol-name)

(defmethod eclector.reader:find-character ((client client) name)
  ;; Accept this implementation's extended character names, such as
  ;; #\Escape, beyond Eclector's portable table.
  (or (call-next-method) (name-char name)))

(defmethod eclector.reader:wrap-in-quote ((client client) material)
  (list :prefix "'" material))

(defmethod eclector.reader:wrap-in-function ((client client) name)
  (list :prefix "#'" name))

(defmethod eclector.reader:wrap-in-quasiquote ((client client) form)
  (list :prefix "`" form))

(defmethod eclector.reader:wrap-in-unquote ((client client) form)
  (list :prefix "," form))

(defmethod eclector.reader:wrap-in-unquote-splicing ((client client) form)
  (list :prefix ",@" form))

(defmethod eclector.reader:evaluate-expression ((client client) expression)
  (list :prefix "#." expression))

(defmethod eclector.reader:evaluate-feature-expression
    ((client client) expression)
  (labels ((feature-p (expression)
             (typecase expression
               (string (and (member expression *features*
                                    :test #'string-equal)
                            t))
               (cons
                (let ((operator (first expression)))
                  (when (stringp operator)
                    (cond ((string-equal operator "and")
                           (every #'feature-p (rest expression)))
                          ((string-equal operator "or")
                           (some #'feature-p (rest expression)))
                          ((string-equal operator "not")
                           (not (feature-p (second expression))))))))
               (t nil))))
    (feature-p expression)))

(defmethod eclector.reader:check-feature-expression
    ((client client) expression)
  (declare (ignore expression))
  t)

(defun node-children (children)
  (remove-if-not (lambda (child) (typep child 'node)) children))

(defun guard-prefix-at (text start)
  (and (< (1+ start) (length text))
       (char= (char text start) #\#)
       (member (char text (1+ start)) '(#\+ #\-))
       (subseq text start (+ start 2))))

(defun dotted-tail-p (result)
  (and (consp result)
       (loop for tail = result then (cdr tail)
             when (atom tail) return (not (null tail)))))

(defmethod eclector.parse-result:make-expression-result
    ((client client) result children source)
  (let* ((start (car source))
         (end (cdr source))
         (text (client-text client))
         (slice (subseq text start end))
         (children (node-children children))
         (forms (remove-if #'remark-p children)))
    (cond
      ((and (consp result) (eq (first result) :prefix))
       (wrap (second result) (first (last forms)) start end))
      ((and (guard-prefix-at text start) (= (length forms) 2))
       (guard (guard-prefix-at text start)
              (first forms) (second forms) start end))
      ((char= (char slice 0) #\()
       (paren "(" (place-list-dot result children text) start end))
      ((and (>= (length slice) 2) (string= slice "#(" :end1 2))
       (paren "#(" children start end))
      (t (raw slice start end)))))

(defun place-list-dot (result children text)
  "Insert a dot atom into a dotted list's children."
  (if (and (dotted-tail-p result) (>= (length children) 2))
      (let* ((tail (last children 2))
             (dot (position #\. text
                            :start (node-end (first tail))
                            :end (node-start (second tail)))))
        (if dot
            (append (butlast children 1)
                    (list (raw "." dot (1+ dot)) (first tail)))
            children))
      children))

(defmethod eclector.parse-result:make-skipped-input-result
    ((client client) stream reason children source)
  (declare (ignore stream children))
  (let ((start (car source))
        (end (cdr source)))
    (cond ((or (and (consp reason)
                    (member (car reason)
                            '(:sharpsign-plus :sharpsign-minus)))
               (member reason '(:sharpsign-plus :sharpsign-minus)))
           (pending start end))
          ((or (eq reason :block-comment)
               (and (consp reason) (eq (car reason) :line-comment)))
           (let ((slice (string-right-trim
                         '(#\Newline #\Return)
                         (subseq (client-text client) start end))))
             (remark slice start (+ start (length slice)))))
          (t :discard))))

;;; Reading and post-processing

(defun read-nodes (client stream)
  (let ((eof (list :eof))
        (nodes '()))
    (loop
      (multiple-value-bind (result orphans)
          (eclector.parse-result:read client stream nil eof)
        (dolist (orphan (node-children orphans))
          (push orphan nodes))
        (when (eq result eof)
          (return))
        (push result nodes)))
    (nreverse nodes)))

(defun reparse-guard (client node)
  "Re-read a guard whose branch was rejected during the first pass."
  (let* ((start (pending-start node))
         (text (client-text client))
         (stream (make-string-input-stream text)))
    (file-position stream (+ start 2))
    (let* ((condition (eclector.parse-result:read client stream))
           (form (eclector.parse-result:read client stream)))
      (guard (guard-prefix-at text start) condition form
             start (pending-end node)))))

(defun resolve (node client)
  "Replace PENDING guards throughout NODE by their re-read forms."
  (etypecase node
    (pending (resolve (reparse-guard client node) client))
    (paren
     (setf (paren-items node)
           (mapcar (lambda (item) (resolve item client))
                   (paren-items node)))
     node)
    (wrap
     (setf (wrap-child node) (resolve (wrap-child node) client))
     node)
    (guard
     (setf (guard-condition node) (resolve (guard-condition node) client)
           (guard-form node) (resolve (guard-form node) client))
     node)
    ((or raw remark) node)))

(defun arrange (nodes text)
  "Insert blank-line gaps between nodes and mark trailing remarks,
recursively, using source positions."
  (let ((result '())
        (previous nil))
    (dolist (node nodes)
      (arrange-children node text)
      (when previous
        (let ((newlines (count #\Newline text
                               :start (node-end previous)
                               :end (node-start node))))
          (cond ((>= newlines 2) (push (gap) result))
                ((and (remark-p node) (zerop newlines))
                 (setf (remark-trailing-p node) t)))))
      (push node result)
      (setf previous node))
    (nreverse result)))

(defun arrange-children (node text)
  (etypecase node
    (paren (setf (paren-items node) (arrange (paren-items node) text)))
    (wrap (arrange-children (wrap-child node) text))
    (guard (arrange-children (guard-condition node) text)
           (arrange-children (guard-form node) text))
    ((or raw remark) nil)))

(defun parse (source)
  (let* ((client (make-instance 'client :text source))
         (stream (make-string-input-stream source)))
    (arrange (mapcar (lambda (node) (resolve node client))
                     (read-nodes client stream))
             source)))

;;; Token equivalence, for checking that formatting reorders nothing.

(defun source-tokens (source)
  "The source's token stream: everything but whitespace."
  (let ((tokens '()))
    (labels ((walk (node)
               (etypecase node
                 (raw (push (raw-text node) tokens))
                 (remark (push (remark-text node) tokens))
                 (gap)
                 (wrap (push (wrap-prefix node) tokens)
                       (walk (wrap-child node)))
                 (guard (push (guard-prefix node) tokens)
                        (walk (guard-condition node))
                        (walk (guard-form node)))
                 (paren (push (paren-open node) tokens)
                        (mapc #'walk (paren-items node))
                        (push ")" tokens)))))
      (mapc #'walk (parse source)))
    (nreverse tokens)))

;;; Layout
;;;
;;; NODE-DOCS returns two values: the full document, whose choices
;;; already include the one-line layout, and the one-line layout alone
;;; (or NIL when comments or multi-line strings rule it out), for
;;; embedding in a parent's head line.

(defvar *data-context-p* nil
  "True inside quoted or vector structure, where lists are data and
their elements flow as a filled paragraph instead of code lines.")

(defparameter *body-rules*
  '(("defun" 2) ("defmacro" 2) ("defmethod" 2) ("defgeneric" 2)
    ("deftype" 2) ("define-condition" 2) ("defclass" 2) ("defsystem" 1)
    ("defstruct" 1) ("defpackage" 1)
    ("defvar" 2) ("defparameter" 2) ("defconstant" 2)
    ("lambda" 1) ("let" 1) ("let*" 1)
    ("flet" 1 :functions) ("labels" 1 :functions) ("macrolet" 1 :functions)
    ("when" 1) ("unless" 1)
    ;; The fourth field is the number of leading forms in each body clause.
    ;; Those forms stay on the clause head; the remaining forms are offered
    ;; as a two-space-indented body instead of generic call arguments.
    ("cond" 0 nil 1)
    ("case" 1 nil 1) ("ecase" 1 nil 1) ("ccase" 1 nil 1)
    ("typecase" 1 nil 1) ("etypecase" 1 nil 1) ("ctypecase" 1 nil 1)
    ("dolist" 1) ("dotimes" 1) ("block" 1) ("catch" 1)
    ("multiple-value-bind" 2) ("destructuring-bind" 2)
    ("handler-case" 1 nil 2) ("handler-bind" 1)
    ("restart-case" 1 nil 2)
    ("eval-when" 1) ("progn" 0) ("prog1" 1) ("unwind-protect" 1))
  "Body forms: distinguished argument count, and optionally :FUNCTIONS
when the first distinguished argument is a list of local function
definitions that should each format like a DEFUN.")

(defparameter *hanging-only-heads*
  '("function" "go" "if" "load-time-value" "locally"
    "multiple-value-call" "multiple-value-prog1" "progv" "quote"
    "return-from" "setq" "symbol-macrolet" "tagbody" "the" "throw")
  "Special operators not already handled by body rules. Their conventional
broken layout keeps the first operand beside the operator.")

(defun bare-name (name)
  (let ((colon (position #\: name :from-end t)))
    (if colon (subseq name (1+ colon)) name)))

(defun body-rule (name)
  (let ((bare (bare-name name)))
    (or (rest (assoc bare *body-rules* :test #'string-equal))
        (when (and (>= (length bare) 5)
                   (string-equal "with-" bare :end2 5))
          '(1))
        (when (and (>= (length bare) 3)
                   (string-equal "do-" bare :end2 3))
          '(1)))))

(defun fill-head-p (head)
  "Lists whose elements flow as a filled paragraph: quoted data,
keyword-headed clauses, and LOOP."
  (and (raw-p head)
       (let ((name (raw-text head)))
         (or *data-context-p*
             (and (plusp (length name)) (char= (char name 0) #\:))
             (string-equal "loop" (bare-name name))))))

(defparameter *loop-clause-heads*
  '("named" "initially" "finally" "with" "for" "as" "repeat"
    "while" "until" "always" "never" "thereis" "collect" "collecting"
    "append" "appending" "nconc" "nconcing" "count" "counting" "sum"
    "summing" "maximize" "maximizing" "minimize" "minimizing" "do"
    "doing" "return" "if" "when" "unless" "else" "end" "and"))

(defun loop-clause-head-p (item)
  (and (raw-p item)
       (member (bare-name (raw-text item)) *loop-clause-heads*
               :test #'string-equal)))

(defun loop-tail-doc (items)
  "Group LOOP tokens into clauses so line choices occur before WHILE, DO,
FOR, and similar clause heads, never between a clause head and its operand."
  (let ((groups '()) (group '()) (after-and-p nil))
    (dolist (item items)
      (when (and group (loop-clause-head-p item) (not after-and-p))
        (push (nreverse group) groups)
        (setf group nil))
      (push item group)
      (setf after-and-p
            (and (raw-p item)
                 (string-equal "and" (bare-name (raw-text item))))))
    (when group (push (nreverse group) groups))
    (fill-join
     (mapcar (lambda (items)
               (reduce (lambda (left right)
                         (cat left " " (values (node-docs right))))
                       (rest items)
                       :initial-value (values (node-docs (first items)))))
             (nreverse groups)))))

(defun join-flat (flats)
  (reduce (lambda (left right) (cat left " " right)) flats))

(defun fill-join (docs)
  "Join document DOCS with individual space-or-newline choices."
  (reduce (lambda (left right) (cat left (choice " " +newline+) right))
          docs))

(defun keyword-atom-p (item)
  (and (raw-p item)
       (plusp (length (raw-text item)))
       (char= (char (raw-text item) 0) #\:)))

(defun pair-keywords (items)
  "Pair each keyword atom with the following form, so that plists such
as :test #'eq keep keyword and value on one line."
  (loop with result = '()
        while items
        do (let ((item (pop items)))
             (if (and (keyword-atom-p item)
                      items
                      (typep (first items) '(or raw wrap guard paren)))
                 (push (list :pair item (pop items)) result)
                 (push item result)))
        finally (return (nreverse result))))

(defun pair-docs (pair)
  (destructuring-bind (key value) (rest pair)
    (multiple-value-bind (value-doc value-flat) (node-docs value)
      (let ((keyword (values (node-docs key))))
        (values (choice (cat keyword " " value-doc)
                        (cat keyword (nest 2 (cat +newline+ value-doc))))
                (when value-flat (cat keyword " " value-flat)))))))

(defun stack-docs (items &optional clause-head-count)
  "Lay ITEMS out vertically, honoring gaps and trailing remarks.
Returns the vertical document, the one-line document or NIL, and
whether the last line ends in a remark."
  (let ((lines '())
        (flats '())
        (flat-p t)
        (gap-pending-p nil)
        (ends-with-remark-p nil))
    (dolist (item (pair-keywords items))
      (etypecase item
        (gap (setf gap-pending-p t flat-p nil))
        (remark
         (setf flat-p nil)
         (if (and (remark-trailing-p item) lines (not gap-pending-p))
             (setf (car (first lines))
                   (cat (car (first lines)) " "
                        (span :comment (remark-text item))))
             (progn
               (push (cons (span :comment (verbatim (remark-text item)))
                           gap-pending-p)
                     lines)
               (setf gap-pending-p nil)))
         (setf ends-with-remark-p t))
        ((or raw wrap guard paren cons)
         (multiple-value-bind (document flat)
             (cond ((consp item) (pair-docs item))
                   ((and clause-head-count (paren-p item))
                    (clause-docs item clause-head-count))
                   (t (node-docs item)))
           (push (cons document gap-pending-p) lines)
           (setf gap-pending-p nil ends-with-remark-p nil)
           (if flat (push flat flats) (setf flat-p nil))))))
    (setf lines (nreverse lines))
    (values
     (when lines
       (reduce (lambda (left line)
                 (destructuring-bind (document . gap-first-p) line
                   (if gap-first-p
                       (cat left +newline+ +newline+ document)
                       (cat left +newline+ document))))
               (rest lines)
               :initial-value (car (first lines))))
     (when (and flat-p flats)
       (join-flat (nreverse flats)))
     ends-with-remark-p)))

(defun close-paren (ends-with-remark-p)
  (if ends-with-remark-p (cat +newline+ ")") ")"))

(defun clause-docs (node head-count)
  "A CASE-like clause: keep HEAD-COUNT leading forms on its head and
offer the remaining forms as a body nested two spaces from the opening."
  (let* ((items (paren-items node))
         (split (min head-count (length items)))
         (head-items (subseq items 0 split))
         (body-items (nthcdr split items)))
    (when (or (< (length head-items) head-count)
              (some (lambda (item) (or (gap-p item) (remark-p item)))
                    head-items))
      (return-from clause-docs (paren-docs node)))
    (multiple-value-bind (head-doc head-flat)
        (stack-docs head-items)
      (multiple-value-bind (body-doc body-flat ends-with-remark-p)
          (stack-docs body-items)
        (let* ((head (cat (paren-open node) (or head-flat head-doc)))
               (broken (if body-doc
                           (cat head (nest 2 (cat +newline+ body-doc))
                                (close-paren ends-with-remark-p))
                           (cat head ")")))
               (flat (when (and head-flat body-flat)
                       (cat (paren-open node) head-flat " " body-flat ")"))))
          (if flat
              (values (choice flat broken) flat)
              (values broken nil)))))))

(defun stack-list (docs)
  (reduce (lambda (left right) (cat left +newline+ right)) docs))

(defun specials-head (open operator specials binding-style)
  "The head line: opening, operator, and distinguished arguments, on
one line when they fit or aligned under the first otherwise."
  (let ((docs '())
        (flats '())
        (flat-p t))
    (dolist (special specials)
      (multiple-value-bind (document flat)
          (if (and (eq binding-style :functions) (paren-p special))
              (binding-list-docs special)
              (node-docs special))
        (push document docs)
        (if flat (push flat flats) (setf flat-p nil))))
    (setf docs (nreverse docs) flats (nreverse flats))
    (let ((head (cat open (span :special operator))))
      (cond ((null specials) head)
            (flat-p
             (choice (cat head " " (join-flat flats))
                     (cat head " " (align (stack-list docs)))))
            (t (cat head " " (align (stack-list docs))))))))

(defun binding-list-docs (bindings)
  "A FLET or LABELS binding list: each binding formats like a DEFUN."
  (let ((docs '())
        (flats '())
        (flat-p t))
    (dolist (item (paren-items bindings))
      (etypecase item
        ((or gap remark) (setf flat-p nil))
        (paren
         (multiple-value-bind (document flat) (paren-docs item '(1))
           (push document docs)
           (if flat (push flat flats) (setf flat-p nil))))
        ((or raw wrap guard)
         (multiple-value-bind (document flat) (node-docs item)
           (push document docs)
           (if flat (push flat flats) (setf flat-p nil))))))
    (setf docs (nreverse docs) flats (nreverse flats))
    (let* ((broken (cat "(" (align (stack-list docs)) ")"))
           (flat (when (and flat-p flats)
                   (cat "(" (join-flat flats) ")"))))
      (if flat
          (values (choice flat broken) flat)
          (values broken nil)))))

(defun rule-docs (node rule)
  "Body-form layout: distinguished arguments on the head line, body
indented two below. Returns NIL when the shape does not apply."
  (destructuring-bind (count &optional binding-style clause-head-count) rule
    (let* ((items (paren-items node))
           (operator (raw-text (first items)))
           (specials (subseq items 1 (min (length items) (1+ count))))
           (body (nthcdr (1+ count) items)))
      (when (and (= (length specials) count)
                 body
                 (notany (lambda (item)
                           (or (remark-p item) (gap-p item)))
                         specials))
        (multiple-value-bind (body-doc body-flat ends-with-remark-p)
            (stack-docs body clause-head-count)
          (declare (ignore body-flat))
          (cat (specials-head (paren-open node) operator specials
                              binding-style)
               (nest 2 (cat +newline+ body-doc))
               (close-paren ends-with-remark-p)))))))

(defun call-docs (node)
  "Function-call layouts: arguments either hang under the first or form a
two-space-indented vertical body below the operator."
  (let* ((items (paren-items node))
         (head (first items)))
    (multiple-value-bind (head-doc head-flat) (node-docs head)
      (declare (ignore head-flat))
      (multiple-value-bind (arguments-doc arguments-flat
                            ends-with-remark-p)
          (stack-docs (rest items))
        (declare (ignore arguments-flat))
        (if arguments-doc
            (let ((close (close-paren ends-with-remark-p)))
              (let ((hanging
                      (cat (paren-open node) head-doc " "
                           (align arguments-doc) close)))
                (if (and (raw-p head)
                         (not (member (bare-name (raw-text head))
                                      *hanging-only-heads*
                                      :test #'string-equal)))
                    (choice hanging
                            (cat (paren-open node) head-doc
                                 (nest 2 (cat +newline+ arguments-doc)) close))
                    hanging)))
            (cat (paren-open node) head-doc ")"))))))

(defun fill-docs (node)
  "Paragraph layout for data: elements flow, breaking where needed."
  (let ((items (paren-items node)))
    (when (notany (lambda (item) (or (remark-p item) (gap-p item)))
                  items)
      (if (rest items)
          (multiple-value-bind (head-doc) (node-docs (first items))
            (let* ((loop-p (and (raw-p (first items))
                                (string-equal
                                 "loop" (bare-name
                                         (raw-text (first items))))))
                   (tail (if loop-p
                             (loop-tail-doc (rest items))
                             (fill-join
                              (mapcar (lambda (item)
                                        (values (node-docs item)))
                                      (rest items))))))
              (let ((hanging (cat (paren-open node) head-doc " "
                                  (align tail) ")")))
                (if loop-p
                    (choice hanging
                            (cat (paren-open node) head-doc
                                 (nest 2 (cat +newline+ tail)) ")"))
                    hanging))))
          (cat (paren-open node)
               (values (node-docs (first items)))
               ")")))))

(defun paren-docs (node &optional forced-rule)
  (let ((items (paren-items node)))
    (when (null items)
      (let ((empty (cat (paren-open node) ")")))
        (return-from paren-docs (values empty empty))))
    (multiple-value-bind (all-doc all-flat ends-with-remark-p)
        (stack-docs items)
      (let* ((head (first items))
             (flat (when all-flat
                     (cat (paren-open node) all-flat ")")))
             (broken
               (or (when (and forced-rule (raw-p head))
                     (rule-docs node forced-rule))
                   (when (and (raw-p head)
                              (not *data-context-p*)
                              (not forced-rule))
                     (let ((rule (body-rule (raw-text head))))
                       (when rule (rule-docs node rule))))
                   (when (fill-head-p head)
                     (fill-docs node))
                   (if (and (raw-p head) (rest items))
                       (call-docs node)
                       (cat (paren-open node)
                            (align all-doc)
                            (close-paren ends-with-remark-p))))))
        (if flat
            (values (choice flat broken) flat)
            (values broken nil))))))

(defun node-docs (node)
  (etypecase node
    (raw
     (let* ((source (raw-text node))
            (meta (cond ((char= (char source 0) #\") :string)
                        ((char= (char source 0) #\:) :keyword)))
            (document (verbatim source))
            (document (if meta (span meta document) document)))
       (if (find #\Newline source)
           (values document nil)
           (values document document))))
    (remark
     (values (span :comment (verbatim (remark-text node))) nil))
    (wrap
     (let* ((prefix (wrap-prefix node))
            (*data-context-p*
              (cond ((string= prefix "'") t)
                    ((string= prefix "`") nil)
                    ((member prefix '("," ",@" ",.") :test #'string=) nil)
                    (t *data-context-p*))))
       (multiple-value-bind (document flat) (node-docs (wrap-child node))
         (values (if (string= prefix "`")
                     (cat prefix (align document))
                     (cat prefix document))
                 (when flat (cat prefix flat))))))
    (guard
     (multiple-value-bind (condition-doc condition-flat)
         (node-docs (guard-condition node))
       (multiple-value-bind (form-doc form-flat)
           (node-docs (guard-form node))
         (declare (ignore form-flat))
         (let ((head (cat (guard-prefix node)
                          (or condition-flat condition-doc))))
           ;; Reader conditionals are visual boundaries, not ordinary
           ;; prefixes: keep the condition and guarded form on separate lines
           ;; even when their combined text would fit.
           (values (cat head +newline+ form-doc) nil)))))
    (paren
     (let ((*data-context-p*
             (or *data-context-p*
                 (string= (paren-open node) "#("))))
       (paren-docs node)))))

;;; ANSI terminal styling
;;;
;;; The formatter wraps strings, keywords, comments, and body-form
;;; operators in spans; rendering into an ANSI-STREAM interprets them
;;; as SGR codes, while plain streams ignore them.

(defclass ansi-stream (sb-gray:fundamental-character-output-stream)
  ((target :initarg :target :reader ansi-target)
   (stack :initform '() :accessor ansi-stack)))

(defmethod sb-gray:stream-write-char ((stream ansi-stream) char)
  (write-char char (ansi-target stream)))

(defmethod sb-gray:stream-write-string ((stream ansi-stream) string
                                        &optional (start 0) end)
  (write-string string (ansi-target stream)
                :start start :end (or end (length string)))
  string)

(defmethod sb-gray:stream-line-column ((stream ansi-stream))
  nil)

(defun span-code (meta)
  (case meta
    (:special "1")
    (:comment "2")
    (:string "32")
    (:keyword "36")))

(defun write-span-code (stream code)
  (format (ansi-target stream) "~C[~Am" #\Escape code))

(defmethod render-layout ((document span-document) (stream ansi-stream)
                          last base)
  (let ((code (span-code (span-document-meta document))))
    (if code
        (progn
          (push (span-document-meta document) (ansi-stack stream))
          (write-span-code stream code)
          (prog1 (call-next-method)
            (pop (ansi-stack stream))
            (write-span-code stream "0")
            (dolist (outer (reverse (ansi-stack stream)))
              (write-span-code stream (span-code outer)))))
        (call-next-method))))

;;; Driving

(defun format-source (source &key (width 80) style)
  "Format Lisp SOURCE text optimally within WIDTH columns. STYLE :ANSI
renders span annotations as terminal colors."
  (let ((cost (make-f2 width))
        (chunks '()))
    (flet ((emit (document)
             (with-output-to-string (plain)
               (render (result-candidate (pick document cost))
                       (ecase style
                         ((nil) plain)
                         (:ansi (make-instance 'ansi-stream
                                               :target plain)))))))
      (dolist (item (parse source))
        (etypecase item
          (gap (when chunks
                 (setf (first chunks)
                       (cons (car (first chunks)) t))))
          (remark
           (let ((text (emit (span :comment
                                   (verbatim (remark-text item))))))
             (if (and (remark-trailing-p item) chunks)
                 (setf (first chunks)
                       (cons (concatenate 'string (car (first chunks))
                                          " " text)
                             (cdr (first chunks))))
                 (push (cons text nil) chunks))))
          ((or raw wrap guard paren)
           (push (cons (emit (values (node-docs item))) nil) chunks)))))
    (setf chunks (nreverse chunks))
    (with-output-to-string (output)
      (loop for (chunk . gap-after-p) in chunks
            do (write-string chunk output)
               (terpri output)
               (when gap-after-p (terpri output))))))

(defun format-file (path &key (width 80) style)
  "Format the file at PATH, returning the result as a string."
  (format-source
   (with-open-file (stream path :direction :input)
     (let ((source (make-string (file-length stream))))
       (subseq source 0 (read-sequence source stream))))
   :width width :style style))
