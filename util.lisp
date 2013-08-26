(in-package :weblocks-cms)

(defun implode (glue-or-pieces &optional (pieces nil pieces-given-p))
  (unless pieces-given-p 
    (return-from implode (implode "" glue-or-pieces)))

  (format nil "~{~A~}"
          (cdr (loop for i in pieces append 
                     (list glue-or-pieces i)))))
 
(setf (fdefinition 'join) (fdefinition 'implode))

(defun htmlspecialchars (text)
  (arnesi:escape-as-html text))

(defun strip-tags (text)
  (labels ((get-node-text (dom)
             "Recursive function for getting node text"
             (if (dom:text-node-p dom)
               (dom:node-value dom)
               (join 
                 (loop for i across (dom:child-nodes dom) collect (get-node-text i))))))
    (htmlspecialchars 
      (get-node-text 
        (chtml:parse text (cxml-dom:make-dom-builder))))))

(defvar *models-package*)

(defun keyword->symbol (keyword)
  (intern (string-upcase keyword) *models-package*))

(defun safe-parse-integer (number)
  (if (not number)
    0
    (parse-integer number :junk-allowed t)))

(defun explode (delimiter string)
  (ppcre:split 
    (ppcre:quote-meta-chars delimiter)
    string))
