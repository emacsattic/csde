;;; csde-help.el
;; $Revision$ 

;; Adapted from the JDE by Matt Bruce <matt.bruce@morganstanley.com>
;; Maintainer:  Matt Bruce

;; Copyright (C) 2001 by Matt Bruce

;; JDE Author: Paul Kinnucan <paulk@mathworks.com>, Phillip Lord <plord@hgmp.mrc.ac.uk>
;; JDE Maintainer: Paul Kinnucan

;; Keywords: csharp, tools

;; JDE version Copyright (C) 1999, 2001 Paul Kinnucan.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;; The latest version of the CSDE is available at
;; <URL:http://www.sourceforge.com/>.

;; Please send any comments, bugs, or upgrade requests to
;; Matt Bruce (matt.bruce@morganstanley.com)

(require 'beanshell)
(require 'csde-widgets)
(require 'eieio)

(defcustom csde-help-docsets nil
  "*Lists collections of HTML files documenting Csharp classes. 
This list is used by the `csde-help-class' command to find help for 
a class. You can specify the following information for each docset:

Docset type

  The following types are valid: 

  * csharpdoc. 

    Collections generated by the csharpdoc command.

  * Other

    Collections of HTML class documentation files generated by some
    other means.

Docset directory

   Directory containing the collection, e.g., d:/jdk1.2/docs/api.

Doc lookup function

   Should specify a function that accepts a fully qualified class name, 
   e.g., csharp.awt.String, and a docset directory and returns a path to 
   an HTML file that documents that class, e.g., 
   d:/jdk1.2/docs/api/csharp/awt/String.html. This field must be specified
   for non-csharpdoc collections. It is ignored for csharpdoc colletions.
"
  :group 'csde-project
  :type '(repeat 
	  (list
	   (radio-button-choice
	    :format "%t \n%v"
	    :tag "Docset type:"
	    (const "csharpdoc")
	    (const "Other"))
	   (file :tag "Docset directory")
	   (function :tag "Doc lookup function:"))))

(defun csde-help-docset-get-type (docset)
  (nth 0 docset))

(defun csde-help-docset-get-dir (docset)
  (nth 1 docset))

(defun csde-help-docset-get-lookup-function (docset)
  (nth 2 docset))


(defun csde-help-lookup-csharp1-csharpdoc (class docset-dir) 
  (let ((doc-path
	 (concat 
	  (expand-file-name class docset-dir)
	  ".html")))
    (if (file-exists-p doc-path) 
	doc-path)))

(defun csde-help-lookup-csharp2-csharpdoc (class docset-dir) 
  (let ((doc-path
	 (concat 
	  (expand-file-name 
	   (substitute ?/ ?. class) 
	   docset-dir)
	  ".html")))
    (if (file-exists-p doc-path) 
	doc-path)))


(defun csde-help-get-doc (class) 
"Gets path to the HTML file for CLASS where CLASS is a 
qualified class name."
  (if class
      (cond 
       ((not csde-help-docsets)
	(error "%s" "Help error: No docsets available. See csde-help-docsets."))
       (t
	(let ((paths
	       (mapcar
		(lambda (docset)
		  (cond
		   ((string= (csde-help-docset-get-type docset) "csharpdoc")
		    (or 
		     (csde-help-lookup-csharp1-csharpdoc
		      class
		      (csde-help-docset-get-dir docset)) 
		     (csde-help-lookup-csharp2-csharpdoc
		      class
		      (csde-help-docset-get-dir docset))))
		   (t
		    (apply
		     (csde-help-docset-get-lookup-function docset)
		     class
		     (csde-help-docset-get-dir docset)))))
		csde-help-docsets)))
	  (setq paths (delq nil paths))
	  ;; Return first file found.
	  (if paths (car paths) paths))))))


(defun csde-help-symbol ()
  "Displays help for the symbol at point. The symbol may reference an object, a class,
or a method or field. If the symbol references a class, this function displays the 
csharpdoc for the class. If the symbol references an object,  this method 
displays the csharpdoc for the class of the object. If the symbol references a field or
a method, this function displays the csharpdoc for the class of the object of which
the field or method is a member. Eventually this function will be enhanced to position
the csharpdoc at the point where the method or field is documented."
  (interactive)
  (condition-case err
      (let* ((unqualified-name (thing-at-point 'symbol))
	     (class-names 
	      (bsh-eval-r 
	       (concat "csde.util.CsdeUtilities.getQualifiedName(\"" unqualified-name
		       "\");"))))
	(if (not class-names)
	    (let ((parse-result (csde-help-parse-symbol-at-point)))
	      (if parse-result	      
		  (setq unqualified-name  (car parse-result)))
	      (setq class-names 
		    ;;expand the names into full names, or a list of names
		    (bsh-eval-r 
		     (concat "csde.util.CsdeUtilities.getQualifiedName(\"" unqualified-name "\");")))))
   
	;;Check return value of QualifiedName
	(if class-names
	    (let ((doc-files (mapcar 'csde-help-get-doc class-names)))
	      (if doc-files
		  (progn
		    ;;Remove any annoying nils from the returned values
		    (setq doc-files (delq nil doc-files))
		    (if (eq 1 (length doc-files))
			;;then show it
			(csde-help-show-document (car doc-files))
		      ;;else let the user choose
		      ;;If the list is only one long
		      (csde-help-choose-document doc-files)))
		(error "Cannot find documentation for %s" unqualified-name)))
	  (error "Cannot find %s" unqualified-name)))
    (error
     (message "%s" (error-message-string err)))))
  

(defun csde-help-show-document (doc-file)
  "Actually displays the document."
  (if (not (eq doc-file nil))
      (browse-url (format "file://%s" doc-file))))

(defun csde-help-choose-document(doc-files)
  "Allows the user to select which of the possible documentation files they wish to view."
  (let ((buf (get-buffer-create "*Select Class*" )))
    ;; (setq csde-help-documentation-files doc-files)
    (setq csde-help-selected-documentation-file (car doc-files))
    (set-buffer buf)
    (widget-insert "Several documentation files match your class.\n")
    (widget-insert "Select the one you want to view.\n")
    (widget-insert "Then click the OK button.\n\n" )
    (let ((args (list
		 'radio-button-choice
		 :value (car doc-files)
		 :notify (lambda (widget &rest ignore)
			   (setq csde-help-selected-documentation-file (widget-value widget))
			   (message "You selected: %s"
				    (widget-value widget))))))
	  (setq args (nconc
		      args
		       (mapcar (lambda (x) (list 'item x)) doc-files)))
	  (apply 'widget-create args))
    (widget-insert "\n")
    (widget-create 'push-button
		   :notify (lambda (&rest ignore)
			     (let ((dialog-buffer
				    (current-buffer)))
			       (delete-window)
			       (kill-buffer dialog-buffer)
			       (csde-help-show-document csde-help-selected-documentation-file)
			       (message "Viewing initiated.")))
		   "Ok")
    (use-local-map widget-keymap)
    (widget-setup)
    (pop-to-buffer buf)))


(defun csde-help-parse-symbol-at-point ()
  "Returns (cons TYPE MEMBER) where TYPE is the declared type of
the object referenced by the (qualified) name at point and MEMBER is the
field or method referenced by the name if qualified."
  (let ((parse-result (csde-parse-qualified-name-at-point)))
    (if parse-result
	(let* ((qualifier (car parse-result))
	       (name (cdr parse-result))
	       (obj (if qualifier qualifier name))
	       (member (if qualifier name)))
	  (if (not
	       (and 
		qualifier
		(string-match "[.]" qualifier)))
	      (let ((declared-type (csde-parse-declared-type-of obj)))
		(if declared-type
		    (cons declared-type  member))))))))



;;Support for auto open of source code. This is mostly a hack from 
;;csde-help.el. Probably the two should be changed to use the
;;same methods over again...
(defun csde-show-class-source ( &optional unqual-class )
  "Displays source of the class whose name appears at point in the current
Csharp buffer. This command finds only classes that reside in the source paths
specified by `csde-db-source-directories'. You should provide a global setting
for this variable in your .emacs file to accommodate source files that are
not associated with any project."
  (interactive)
  (condition-case err
      (let* ((unqualified-name 
 	      (or unqual-class
		  (read-from-minibuffer "Class: " (thing-at-point 'symbol))))
 	     (class-names 
 	      ;;expand the names into full names, or a list of names
 	      (bsh-eval-r 
 	       (concat 
 		"csde.util.CsdeUtilities.getQualifiedName(\"" 
 		unqualified-name "\");"))))
 	;;Check return value of QualifiedName
 	(if (eq nil class-names)
 	    (error "Cannot find %s" unqualified-name))
	;; Turn off switching project settings to avoid 
	;; resetting csde-db-source-directories.
	(let ((old-value csde-project-context-switching-enabled-p))
	  (setq csde-project-context-switching-enabled-p nil)
	  ;;If the list is only one long
	  (if (eq 1 (length class-names))
	      ;;then show it
	      (progn(other-window 1)
		    (csde-find-class-source (car class-names)))
	     	  ;;else let the user choose
	    (let ((dialog
		   (csde-show-class-source-chooser-dialog
		    "show sources dialog"
		    :classes class-names)))
	      (csde-dialog-show dialog)))
	  (setq csde-project-context-switching-enabled-p old-value)))
    (error
     (message "%s" (error-message-string err)))))


(defclass csde-show-class-source-chooser-dialog (csde-dialog)
  ((classes     :initarg :classes
		:type list
		:documentation
		"Classes that match the unqualified class name.")
   (check-boxes :initarg :check-boxes
		:documentation
		"Radio buttons used to select source file."))
  "Dialog used to specify which classes to show the source for.")

(defmethod csde-dialog-create ((this csde-show-class-source-chooser-dialog))
    (widget-insert "Several classes match the name you specified.\n")
    (widget-insert "Select the ones you want to view.\n")
    (widget-insert "Then click the OK button.\n\n" )

    (let ((items
	   (mapcar
	    (lambda (class)
	      (list
	       'const
	       :format "%v"
	       class))
	    (oref this classes))))

      (oset this check-boxes
	    (widget-create
	     (list 'checklist :entry-format " %b %v\n" :args items)))
      (widget-insert "\n")))

(defmethod csde-dialog-ok ((this csde-show-class-source-chooser-dialog))
  (let ((dialog-buffer (current-buffer)))
    (mapc (lambda (x) 
	    (other-window 1)
	    (csde-find-class-source x)) 
	  (widget-value (oref this check-boxes)))
    (kill-buffer dialog-buffer)))



(provide 'csde-help)

;; $Log$
;; Revision 1.1.1.1  2001/11/27 03:03:40  flannelboy
;; initial check in of csde csharp mode
;;
;; Revision 1.2  2001/02/12 05:38:25  paulk
;; CSDE 2.2.7
;;
;; Revision 1.15  2001/02/04 01:31:13  paulk
;; Changed declaration of customized variables to permit completion of paths.
;;
;; Revision 1.14  2000/10/08 12:55:39  paulk
;; *** empty log message ***
;;
;; Revision 1.13  2000/08/12 04:47:10  paulk
;; Fixed regression error in csde-help-symbol-at-point.
;;
;; Revision 1.12  2000/02/09 05:06:49  paulk
;; Replaced csde-help-class with csde-help-symbol method. The new method
;; gets help for the symbol at point. The symbol may refer to a class,
;; an object, or a method or field.
;;
;; Revision 1.11  2000/02/01 04:11:56  paulk
;; ReleaseNotes.txt
;;
;; Revision 1.10  2000/01/18 07:11:25  paulk
;; Added csde-show-class-source. Thanks to Phil Lord for the initial
;; implementation of this command.
;;
;; Revision 1.9  2000/01/15 08:06:25  paulk
;; Eliminated some globally bound symbols.
;;
;; Revision 1.8  1999/09/30 04:46:10  paulk
;; Fixed typo spotted by David Biesack.
;;
;; Revision 1.7  1999/09/18 03:26:39  paulk
;; Now prepends "file://" to doc file when invoking browse-url. Hopefully
;; this will fix the problem reported by one user where the browser
;; prepends http://www to doc file path.
;;
;; Revision 1.6  1999/08/20 00:44:43  paulk
;; Corrected spelling of Phillip Lord's name.
;;
;; Revision 1.5  1999/06/26 00:00:12  paulk
;; Type csharpdoc now sufficient to specify both Csharp 1 and Csharp 2 csharpdoc docsets.
;;
;; Revision 1.4  1999/06/25 01:38:17  paulk
;; Enhanced to support doc collections of any type.
;;
;; Revision 1.3  1999/06/17 22:27:33  paulk
;; Bug fix.
;;
;; Revision 1.2  1999/06/17 21:53:05  paulk
;; Eliminated separate customization group for help variables.
;;
;; Revision 1.1  1999/06/17 21:47:15  paulk
;; Initial revision
;;

;; End of csde-help.el
