;;; A pretty-printer for Common Lisp source text, built on Zoot.
;;;
;;; Source is read without interning: atoms, strings, and characters stay
;;; raw token text, so formatting needs no packages, preserves case
;;; exactly, and keeps comments, feature guards, and blank lines. Each
;;; top-level form becomes a Zoot document offering one-line and broken
;;; layouts at every level, and PICK finds the optimal layout under the
;;; page-width cost.

(defpackage #:zoot-sexp
  (:use #:cl)
  (:import-from #:zoot
                #:verbatim #:+newline+ #:cat #:choice #:nest #:align
                #:pick #:render #:result-candidate #:make-f2)
  (:export #:format-source #:format-file #:source-tokens))

(in-package #:zoot-sexp)

;;; Source nodes

(defstruct (raw (:constructor raw (text)))
  "An atom, string, or character literal, kept as raw source text."
  (text "" :type string :read-only t))

(defstruct (wrap (:constructor wrap (prefix child)))
  "A read-macro prefix such as ', `, ,@, #', or #. applied to one form."
  (prefix "" :type string :read-only t)
  (child nil :read-only t))

(defstruct (guard (:constructor guard (prefix condition form)))
  "A #+ or #- feature expression guarding one form."
  (prefix "" :type string :read-only t)
  (condition nil :read-only t)
  (form nil :read-only t))

(defstruct (paren (:constructor paren (open items)))
  "A parenthesized form, or a #( vector."
  (open "(" :type string :read-only t)
  (items nil :type list :read-only t))

(defstruct (remark (:constructor remark (text trailing-p)))
  "A comment. Trailing remarks stay on the previous item's line."
  (text "" :type string :read-only t)
  (trailing-p nil :type boolean :read-only t))

(defstruct (gap (:constructor gap ()))
  "A blank line between items.")

;;; Reading

(defstruct (cursor (:constructor cursor (source)))
  (source "" :type string :read-only t)
  (index 0 :type fixnum))

(defun peek (cursor &optional (offset 0))
  (let ((index (+ (cursor-index cursor) offset)))
    (when (< index (length (cursor-source cursor)))
      (char (cursor-source cursor) index))))

(defun advance (cursor)
  (incf (cursor-index cursor)))

(defun grab (cursor start)
  (subseq (cursor-source cursor) start (cursor-index cursor)))

(defun whitespace-p (char)
  (member char '(#\Space #\Tab #\Newline #\Return #\Page)))

(defun delimiter-p (char)
  (or (null char) (whitespace-p char) (find char "()\";'`,")))

(defun scan-atom (cursor)
  (let ((start (cursor-index cursor)))
    (loop
      (let ((char (peek cursor)))
        (cond ((null char) (return))
              ((char= char #\\)
               (advance cursor)
               (when (peek cursor) (advance cursor)))
              ((char= char #\|)
               (advance cursor)
               (loop for inner = (peek cursor)
                     until (or (null inner) (char= inner #\|))
                     do (advance cursor)
                     finally (when inner (advance cursor))))
              ((delimiter-p char) (return))
              (t (advance cursor)))))
    (raw (grab cursor start))))

(defun scan-string (cursor)
  (let ((start (cursor-index cursor)))
    (advance cursor)
    (loop
      (let ((char (peek cursor)))
        (cond ((null char) (error "Unterminated string"))
              ((char= char #\\)
               (advance cursor)
               (when (peek cursor) (advance cursor)))
              ((char= char #\")
               (advance cursor)
               (return))
              (t (advance cursor)))))
    (raw (grab cursor start))))

(defun scan-line-comment (cursor trailing-p)
  (let ((start (cursor-index cursor)))
    (loop for char = (peek cursor)
          until (or (null char) (char= char #\Newline))
          do (advance cursor))
    (remark (grab cursor start) trailing-p)))

(defun scan-block-comment (cursor)
  (let ((start (cursor-index cursor))
        (depth 0))
    (loop
      (let ((char (peek cursor)))
        (cond ((null char) (error "Unterminated block comment"))
              ((and (char= char #\#) (eql (peek cursor 1) #\|))
               (advance cursor)
               (advance cursor)
               (incf depth))
              ((and (char= char #\|) (eql (peek cursor 1) #\#))
               (advance cursor)
               (advance cursor)
               (when (zerop (decf depth)) (return)))
              (t (advance cursor)))))
    (remark (grab cursor start) nil)))

(defun scan-character (cursor)
  (let ((start (cursor-index cursor)))
    (advance cursor)
    (advance cursor)
    (when (peek cursor) (advance cursor))
    (loop for char = (peek cursor)
          until (delimiter-p char)
          do (advance cursor))
    (raw (grab cursor start))))

(defun skip-whitespace (cursor)
  "Skip whitespace, returning the number of newlines crossed."
  (let ((newlines 0))
    (loop for char = (peek cursor)
          while (and char (whitespace-p char))
          do (when (char= char #\Newline) (incf newlines))
             (advance cursor))
    newlines))

(defun read-prefixed-form (cursor)
  (skip-whitespace cursor)
  (read-form cursor))

(defun read-dispatch (cursor)
  (case (peek cursor 1)
    (#\( (advance cursor)
         (advance cursor)
         (paren "#(" (read-body cursor nil)))
    (#\' (advance cursor)
         (advance cursor)
         (wrap "#'" (read-prefixed-form cursor)))
    (#\. (advance cursor)
         (advance cursor)
         (wrap "#." (read-prefixed-form cursor)))
    (#\\ (scan-character cursor))
    (#\| (scan-block-comment cursor))
    ((#\+ #\-)
     (let ((start (cursor-index cursor)))
       (advance cursor)
       (advance cursor)
       (let ((prefix (grab cursor start))
             (condition (read-prefixed-form cursor)))
         (guard prefix condition (read-prefixed-form cursor)))))
    ((#\p #\P)
     (let ((start (cursor-index cursor)))
       (advance cursor)
       (advance cursor)
       (wrap (grab cursor start) (scan-string cursor))))
    (t (scan-atom cursor))))

(defun read-form (cursor)
  (case (peek cursor)
    (#\( (advance cursor)
         (paren "(" (read-body cursor nil)))
    (#\" (scan-string cursor))
    (#\' (advance cursor)
         (wrap "'" (read-prefixed-form cursor)))
    (#\` (advance cursor)
         (wrap "`" (read-prefixed-form cursor)))
    (#\, (advance cursor)
         (case (peek cursor)
           (#\@ (advance cursor)
                (wrap ",@" (read-prefixed-form cursor)))
           (#\. (advance cursor)
                (wrap ",." (read-prefixed-form cursor)))
           (t (wrap "," (read-prefixed-form cursor)))))
    (#\# (read-dispatch cursor))
    (t (scan-atom cursor))))

(defun read-body (cursor toplevel-p)
  (let ((items '()))
    (loop
      (let* ((newlines (skip-whitespace cursor))
             (char (peek cursor)))
        (when (and (>= newlines 2) items (not (gap-p (first items))))
          (push (gap) items))
        (cond ((null char)
               (unless toplevel-p (error "Unbalanced open parenthesis"))
               (return))
              ((char= char #\))
               (when toplevel-p (error "Unbalanced close parenthesis"))
               (advance cursor)
               (return))
              ((char= char #\;)
               (push (scan-line-comment
                      cursor
                      (and (zerop newlines)
                           items
                           (not (gap-p (first items)))
                           t))
                     items))
              (t (push (read-form cursor) items)))))
    ;; A blank line before the closing parenthesis is dropped.
    (when (and items (gap-p (first items)))
      (pop items))
    (nreverse items)))

(defun parse (source)
  (read-body (cursor source) t))

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
    ("case" 1) ("ecase" 1) ("ccase" 1)
    ("typecase" 1) ("etypecase" 1) ("ctypecase" 1)
    ("dolist" 1) ("dotimes" 1) ("block" 1) ("catch" 1)
    ("multiple-value-bind" 2) ("destructuring-bind" 2)
    ("handler-case" 1) ("handler-bind" 1) ("restart-case" 1)
    ("eval-when" 1) ("progn" 0) ("prog1" 1) ("unwind-protect" 1))
  "Body forms: distinguished argument count, and optionally :FUNCTIONS
when the first distinguished argument is a list of local function
definitions that should each format like a DEFUN.")

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
      (let ((keyword (raw-text key)))
        (values (choice (cat keyword " " value-doc)
                        (cat keyword (nest 2 (cat +newline+ value-doc))))
                (when value-flat (cat keyword " " value-flat)))))))

(defun stack-docs (items)
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
                   (cat (car (first lines)) " " (remark-text item)))
             (progn
               (push (cons (verbatim (remark-text item)) gap-pending-p)
                     lines)
               (setf gap-pending-p nil)))
         (setf ends-with-remark-p t))
        ((or raw wrap guard paren cons)
         (multiple-value-bind (document flat)
             (if (consp item) (pair-docs item) (node-docs item))
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
    (let ((head (cat open operator)))
      (cond ((null specials) head)
            (flat-p
             (choice (cat head " " (join-flat flats))
                     (cat head " " (align (stack-list docs)))))
            (t (cat head " " (align (stack-list docs))))))))

(defun stack-list (docs)
  (reduce (lambda (left right) (cat left +newline+ right)) docs))

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
  (destructuring-bind (count &optional binding-style) rule
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
            (stack-docs body)
          (declare (ignore body-flat))
          (cat (specials-head (paren-open node) operator specials
                              binding-style)
               (nest 2 (cat +newline+ body-doc))
               (close-paren ends-with-remark-p)))))))

(defun call-docs (node)
  "Function-call layout: arguments aligned under the first."
  (let* ((items (paren-items node))
         (head (first items)))
    (multiple-value-bind (head-doc head-flat) (node-docs head)
      (declare (ignore head-flat))
      (multiple-value-bind (arguments-doc arguments-flat
                            ends-with-remark-p)
          (stack-docs (rest items))
        (declare (ignore arguments-flat))
        (if arguments-doc
            (cat (paren-open node) head-doc " "
                 (align arguments-doc)
                 (close-paren ends-with-remark-p))
            (cat (paren-open node) head-doc ")"))))))

(defun fill-docs (node)
  "Paragraph layout for data: elements flow, breaking where needed."
  (let ((items (paren-items node)))
    (when (notany (lambda (item) (or (remark-p item) (gap-p item)))
                  items)
      (let ((docs (mapcar #'node-docs items)))
        (if (rest docs)
            (multiple-value-bind (head-doc) (node-docs (first items))
              (cat (paren-open node) head-doc " "
                   (align (fill-join (mapcar (lambda (item)
                                               (values (node-docs item)))
                                             (rest items))))
                   ")"))
            (cat (paren-open node) (first docs) ")"))))))

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
     (let ((source (raw-text node)))
       (if (find #\Newline source)
           (values (verbatim source) nil)
           (values source source))))
    (remark
     (values (verbatim (remark-text node)) nil))
    (wrap
     (let* ((prefix (wrap-prefix node))
            (*data-context-p*
              (cond ((member prefix '("'" "`") :test #'string=) t)
                    ((member prefix '("," ",@" ",.") :test #'string=) nil)
                    (t *data-context-p*))))
       (multiple-value-bind (document flat) (node-docs (wrap-child node))
         (values (cat prefix document)
                 (when flat (cat prefix flat))))))
    (guard
     (multiple-value-bind (condition-doc condition-flat)
         (node-docs (guard-condition node))
       (multiple-value-bind (form-doc form-flat)
           (node-docs (guard-form node))
         (let ((head (cat (guard-prefix node)
                          (or condition-flat condition-doc))))
           (values (choice (cat head " " form-doc)
                           (cat head +newline+ form-doc))
                   (when (and condition-flat form-flat)
                     (cat head " " form-flat)))))))
    (paren
     (let ((*data-context-p*
             (or *data-context-p*
                 (string= (paren-open node) "#("))))
       (paren-docs node)))))

;;; Driving

(defun format-source (source &key (width 80))
  "Format Lisp SOURCE text optimally within WIDTH columns."
  (let ((cost (make-f2 width))
        (chunks '()))
    (dolist (item (parse source))
      (etypecase item
        (gap (when chunks
               (setf (first chunks)
                     (cons (car (first chunks)) t))))
        (remark
         (if (and (remark-trailing-p item) chunks)
             (setf (first chunks)
                   (cons (concatenate 'string (car (first chunks))
                                      " " (remark-text item))
                         (cdr (first chunks))))
             (push (cons (remark-text item) nil) chunks)))
        ((or raw wrap guard paren)
         (push (cons (render (result-candidate
                              (pick (values (node-docs item)) cost)))
                     nil)
               chunks))))
    (setf chunks (nreverse chunks))
    (with-output-to-string (output)
      (loop for (chunk . gap-after-p) in chunks
            do (write-string chunk output)
               (terpri output)
               (when gap-after-p (terpri output))))))

(defun format-file (path &key (width 80))
  "Format the file at PATH, returning the result as a string."
  (format-source
   (with-open-file (stream path :direction :input)
     (let ((source (make-string (file-length stream))))
       (subseq source 0 (read-sequence source stream))))
   :width width))
