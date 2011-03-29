REBOL [
	; -- basic rebol header --
	file:       %glass-libs-packager.r
	version:    1.0.0
	date:       2011-01-31
	purpose:    "A single file which once encapped contains ALL slim libraries.  Easy to use for encap."
	author:     "Maxim Olivier-Adlhoch"
	copyright:  "Copyright © 2011 Maxim Olivier-Adlhoch"
	web:        http://www.moliad.net/dev-tools/glass/

	;-- Licensing details --
	license-type: 'MIT
	license:      {Copyright © 2011 Maxim Olivier-Adlhoch.

		Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
		and associated documentation files (the "Software"), to deal in the Software without restriction, 
		including without limitation the rights to use, copy, modify, merge, publish, distribute, 
		sublicense, and/or sell copies of the Software, and to permit persons to whom the Software 
		is furnished to do so, subject to the following conditions:
		
		The above copyright notice and this permission notice shall be included in all copies or 
		substantial portions of the Software.}
		
	disclaimer: {THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
		INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
		PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
		FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ]
		ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
		THE SOFTWARE.}
		
	;-- Documentaton --
	notes:      "You need slim to use this library (get it at: www.moliad.net/modules/slim/)"
	details: {
		doing this file you can get a reference to all the other standard libs within GLASS.
		
		you can load multiple libs in a single line using expose.
		
			ex:
				do %glass-libs.r
				slim / open / expose 'glass-libs none [gl epoxy-lib sillica-lib marble-lib]

		note that currently, the icons sets are not linked here.   They eventually will be
		as a separate do-able script.
	}
]


;--------------------------------------------------------------------------------
;--------------------------- LINKED WITH SLIM-LINK.r ----------------------------
;--------------------------------------------------------------------------------





;-----------------------------------------------------------------
;- SLiM OBJECT / START
;-----------------------------------------------------------------
SLiM: make object! [
	id:         1       ; this holds the next serial number assigned to a library


	slim-path: what-dir


	; LIBRARY LIST
	; each time a library is opened, its name and object pointer get dumped here.
	; this allows us to share the same object for all calls
	libs: []


	; LIBRARY PATHS
	; a list of paths which describe where you place your libs
	; the last spec is the cache dir (so if you have only one dir,
	; then its both a library path and cache path.)
	paths: []
	
	; SLIMLINK SETUP
	; if this is set to false, then all open calls use the paths dir and use find-path and do.
	; otherwise it will only do libs directly from the link-cache variable instead.
	linked-libs: none


	;----------------
	; open-version
	open-version: 0.0.0     ; use this to store the version of currently opening module. is used by validate, afterwards.


	;----------------
	;-    MATCH-TAGS()
	;----
	match-tags: func [
		"return true if the specified tags match an expected template"
		template [block!]
		tags [block! none!]
		/local tag success
	][
		success = False
		if tags [
			foreach tag template [
				if any [
					all [
						; match all the tags at once
						block? tag
						((intersect tag tags) = tag)
					]
					
					all [
						;word? tag
						found? find tags tag
					]
				][
					success: True
					break
				]
			]
		]
		success
	]
	
	
	;----------------
	;-    VPRINT()
	;----
	verbose:    false   ; display console messages
	verbose-count: 0    ; every vprint depth gets calculated here
	vtabs: []
	vtags: none			; setting this to a block of tags to print, allows vtags to function, making console messages very selective.
	vconsole: none ; setting this to a block, means all console messages go here instead of in the console and can be spied on later !"
	
	vprint: func [
		"verbose print"
		data
		/in "indents after printing"
		/out "un indents before printing use none so that nothing is printed"
		/always "always print, even if verbose is off"
		/error "like always, but adds stack trace"
		/tags ftags "only effective if one of the specified tags exist in vtags"
		/local line do
	][
		;if error [always: true]
		verbose-count: verbose-count + 1
		if any [
			error
			all [
				any [verbose always] 
				either (block? vtags) [
					match-tags vtags ftags
				][
					true
				]
			]
		][
			
			line: copy ""
			if out [remove vtabs]
			append line vtabs
			switch/default (type?/word data) [
				object! [append line mold first data]
				block! [append line rejoin data]
				string! [append line data]
				none! []
			][append line mold reduce data]
			
			if in [insert vtabs "^-"]
			either vconsole [
				append/only vconsole line
			][
				print replace/all line "^/" join "^/" vtabs 
			]
		]
	]
	
	
	
	
	
	;----------------
	;-    VPROBE()
	;----
	vprobe: func [
		"verbose probe"
		data
		/in "indents after probing"
		/out "un indents before probing"
		/always "always print, even if verbose is off"
		/tags ftags "only effective if one of the specified tags exist in vtags"
		/error "like always, but adds stack trace"
		/local line
	][
		;if error [always: true]
		verbose-count: verbose-count + 1
		if any [
			error
			all [
				any [verbose always] 
				either (block? vtags) [
					match-tags vtags ftags
				][
					true
				]
			]
		][
			if out [remove vtabs]
			switch/default (type?/word data) [
				object! [line: mold/all data]
			][line: mold data]
			
			line: rejoin [""  vtabs line]

			print replace/all line "^/" join "^/" vtabs 

			if in [insert vtabs "^-"]
			
		]
		data
	]
	
	
	
	
	
	;----------------
	;-    VON()
	;----
	von: func [/tags lit-tags ][
		verbose: true
		if tags [
			unless block? vtags [
				vtags: copy []
			]
			unless block? lit-tags [
				lit-tags: reduce [lit-tags]
			]
			vtags: union vtags lit-tags 
		]
			
	]
	
	
	;----------------
	;-    VOFF()
	;----
	voff: func [/tags dark-tags] [
		either tags [
			vtags: exclude vtags dark-tags
		][
			verbose: false
		]		
	]
	
	
	;----------------
	;-    VOUT()
	;----
	vout: func [
		/always
		/error
		/tags ftags
		/with xtext "data you wish to print as a comment after the bracket!"
		/return rdata ; use the supplied data as our return data, allows vout to be placed at end of a function
	][
		;if error [always: true]
		verbose-count: verbose-count + 1
		if any [
			error
			all [
				any [verbose always] 
				either (block? vtags) [
					match-tags vtags ftags
				][
					true
				]
			]
		][
			vprint/out/always/tags  either xtext [join "] ; " xtext]["]"] ftags
		][
			vprint/out/tags either xtext [join "] ; " xtext]["]"] ftags
		]
		; this mimics print's functionality where not supplying return value will return unset!, causing an error in a func which expects a return value.
		either return [
			rdata
		][]
	]
	
	
	
	;----------------
	;-    VIN()
	;----
	vin: func [
		txt
		/always
		/error
		/tags ftags [block!]
	][
		verbose-count: verbose-count + 1
		if any [
			error
			all [
				any [verbose always] 
				either (block? vtags) [
					match-tags vtags ftags
				][
					true
				]
			]
		][
			vprint/in/always/tags join txt " [" ftags
		][
			vprint/in/tags join txt " [" ftags
		]
	]
	
	
	
	;----------------
	;-    V??()
	;----
	v??: func [
	    {Prints a variable name followed by its molded value. (for debugging) - (copied from REBOL mezzanines)}
	    'name
	    /tags ftags [block!]
	][
		either tags [
	   		vprint/tags either word? :name [head insert tail form name reduce [": " mold name: get name]] [mold :name] ftags
	   	][
	   		vprint either word? :name [head insert tail form name reduce [": " mold name: get name]] [mold :name]
		]   		
	    :name
	]
	
	
	
	
	
	;----------------
	;-    VFLUSH()
	;----
	vflush: func [/disk logfile [file!]] [
		if block? vconsole [
			forall head vconsole [
				append first vconsole "^/"
			]
			either disk [
				write logfile rejoin head vconsole
			][
				print head vconsole
			]
			clear head vconsole
		]
	]


	;----------------
	;-    VEXPOSE()
	;----
	vexpose: does [
		set in system/words 'von :von
		set in system/words 'voff :voff
		set in system/words 'vprint :vprint
		set in system/words 'vprobe :vprobe
		set in system/words 'vout :vout
		set in system/words 'vin :vin
		set in system/words 'vflush :vflush
		set in system/words 'v?? :v??
	]


	;----------------
	;-    DISK-PRINT()
	;----
	disk-print: func [path][
		if file? path [
			if exists? path [
				; header
				write/append path reduce [
					"^/^/^/---------------------------^/"
					system/script/title
					"^/"
					system/script/path
					"^/"
					now
					"^/---------------------------^/"
				]
					
				; redefine print outs
				system/words/print: func [data] compose  [
					write/append (path) append reform data "^/"
				]
				system/words/prin: func [data] compose [
					write/append (path) reform data
				]
				system/words/probe: func [data] compose [
					write/append (path) append remold data "^/"
				]
			]
		]
	]
	

	;----------------
	;-    FAST()
	;----
	fast: func [ 
		'name
	][
		; probe name
		set name open name none
	]



	;----------------
	;-    OPEN()
	;----
	OPEN: func [ 
		"Open a library module.  If it is already loaded from disk, then it returns the memory cached version instead."
		lib-name [word! string! file!] "The name of the library module you wish to open.  This is the name of the file on disk.  Also, the name in its header, must match. when using a direct file type, lib name is irrelevant, but version must still be qualified."
		version [integer! decimal! none! tuple! word!] "minimal version of the library which you need, all versions should be backwards compatible."
		/within path [file!] "supply an explicit paths dir to use.  ONLY this path is used, libs, slim path and current-dir are ignored."
		/extension ext [string! word! file!] "what extension do we expect.  Its .r by default.  Note: must supply the '.' "
		/new "Re-load the module from disk, even if one exists in cache."
		/expose exp-words [word! block!] "expose words from the lib after its loaded and bound, be mindfull that words are either local or bound to local context, if they have been declared before the call to open."
		/prefix pfx-word [word! string! none!] "use this prefix instead of the default setup in the lib as a prefix to exposed words"
		/local lib lib-file lib-hdr
	][
		vprint/in ["SLiM/Open()  [" lib-name " " version " ] ["]
		lib-name: to-word lib-name ; make sure the name is a word.
		
		
		;probe "--------"
		;probe self/paths
		
		ext: any [ext ".r"]
		
		; any word you want to use for version will disable explicit version needs
		if word? version [
			version: none
		]
		
		either none? linked-libs [
			either file? lib-name [
				lib-file: lib-name
			][
				lib-file: either within [
					 rejoin [dirize path lib-name ext]
				][
					self/find-path to-file rejoin [lib-name ext]
				]
			]
		][
			lib-file: select linked-libs lib-name
		]
		
		
;		if none? version [version: 0.0]
		self/open-version: version  ; store requested version for validate(), which is called in register.
		
		;-----------------------------------------------------------
		; check for existence of library in cache
		lib: self/cached? lib-name
		
		either ((lib <> none) AND (new = none))[
			vprint [ {STEEL|SLiM/open() reusing "} lib-name {"  module} ]
		][
			vprint [ {STEEL|SLiM/open() loading "} lib-file {"  module} ]
			either lib-file [
				do lib-file
				lib: self/cached? lib-name
			][
				vprint ["SLiM/open() ERROR : " lib-name " does not describe an accessible (loadable) library module (paths: " paths ")"]
			]
		]
		
		
		
		
		
		
		; in any case, check if used didn't want to expose new words
		if lib? lib [
			if expose [
				if not none? lib [
					either prefix [
						if string? pfx-word [pfx-word: to-word pfx-word]
						slim/expose/prefix lib exp-words pfx-word
					][
						slim/expose lib exp-words
					]
				]
			]
		]
		
		; clean exit
		lib-name: none
		version: none
		lib-file: none
		lib-hdr: none
		exp-words: none
		pfx-word: none
		vprint/out "]"
		return first reduce [lib lib: none]
	]

	
	;----------------
	;-    REGISTER()
	;----
	REGISTER: func [
		blk
		/header ; private... do not use.  only to be used by slim linker.
			hdrblk [string! block!]
		/local lib-spec pre-io post-io block lib success
	][
		
		vprint/in ["SLiM/REGISTER() ["]
		
		; temporarily set 'lib to self it is later set to the new library
		lib: self
		
		;--------------
		; initialize default library spec
		lib-spec: copy []
		append lib-spec blk

		;--------------
		; link header data when loading library module
		either none? header [
			hdrblk: system/script/header
		][
			if string? hdrblk [
				hdrblk: load hdrblk
			]
			hdrblk: make object! hdrblk
		]
		
		
		;--------------
		; make sure library meets all requirements
		either self/validate(hdrblk) [
			;--------------
			; compile library specification
			lib-spec: head insert lib-spec compose [ 
				header: (hdrblk)
				;just allocate object space
				rsrc-path: copy what-dir
				dir-path: copy what-dir
				
				read-resource: none
				write-resource: none
				load-resource: none
				save-resource: none
				
				; temporarily set these to the slim print tools... 
				; once the object is built, they will be bound to that object
				verbose: false
				vprint: get in lib 'vprint
				vprobe: get in lib 'vprobe
				vin: get in lib 'vin
				von: get in lib 'von
				voff: get in lib 'voff
				vout: get in lib 'vout
				v??: get in lib 'v??
				vflush: get in lib 'vflush
				vconsole: none
				vtags: none
				
			]
			
			
			;--------------
			; create library        
			lib:  make object! lib-spec
			
			
			; set resource-dir local to library
			vprint ["setting  resource path for lib " hdrblk/title]
			vprint ["what-dir: " what-dir]
			if not (exists? lib/rsrc-path:  to-file append copy what-dir rejoin ["rsrc-" lib/header/slim-name "/"]) [
				lib/rsrc-path: none
			]
			
	
			;--------------
			; encompass I/O so that we add the /resource refinement.
			;-         extend I/O ('read/'write/'load/'save)
			pre-io: compose/deep [
				 if (bind 'rsrc-path in lib 'header) [tmp: what-dir change-dir (bind 'rsrc-path in lib 'header)]
			]
			post-io: compose/deep [
				if  (bind 'rsrc-path in lib 'header) [change-dir tmp]
			]
			lib/read-resource: encompass/args/pre/post 'read [ /local tmp] pre-io post-io           
			lib/write-resource: encompass/silent/args/pre/post 'write [/local tmp] pre-io post-io
			lib/load-resource: encompass/args/pre/post 'load [ /local tmp] pre-io post-io
			lib/save-resource: encompass/silent/args/pre/post 'save [/local tmp] pre-io post-io

			
			;--------------
			; cache library
			; this causes the open library to be able to return the library to the 
			; application which opened the library.  open (after do'ing the library file) will then
			; call cached? to get the library ptr and return it to the user.
			SLiM/cache lib


			;--------------
			; auto-init feature of library if it needs dynamic data (like files to load or opening network ports)...
			; or simply copy blocks
			;
			; note that loading inter-dependent slim libs within the --init-- is safe
			either (in lib '--init--) [
				success: lib/--init--
			][
				success: true
			]
			
			
			either success [
				;--------------
				; setup verbose print
				; note that each library uses its own verbose value, so you can print only messages
				; from a specific library and ignore ALL other printouts.
				;------------
				lib/vprint: func first get in self 'vprint bind/copy second get in self 'vprint in lib 'self
				lib/vprobe: func first get in self 'vprobe bind/copy second get in self 'vprobe in lib 'self
				lib/vin: func first get in self 'vin bind/copy second get in self 'vin in lib 'self
				lib/vout: func first get in self 'vout bind/copy second get in self 'vout in lib 'self
				lib/v??: func first get in self 'v?? bind/copy second get in self 'v?? in lib 'self
				lib/von: func first get in self 'von bind/copy second get in self 'von in lib 'self
				lib/voff: func first get in self 'voff bind/copy second get in self 'voff in lib 'self
				lib/vflush: func first get in self 'vflush bind/copy second get in self 'vflush in lib 'self
				
				
			][
				slim/cache/remove lib
				vprint/error ["SLiM/REGISTER() initialisation of module: " lib/header/slim-name " failed!"]
				lib: none
			]
		][
			vprint/error ["SLiM/REGISTER() validation of library: " hdrblk/slim-name"  failed!"]
		]
		vprint/out "]"
		lib
	]
	
	
	
	;----------------
	;-    LIB?()
	;----
	LIB?: func [
		"returns true if you supply a valid library module object, else otherwise."
		lib
	][
		either object! = type? lib [
			either in lib 'header [
				either in lib/header 'slim-version [
					return true
				][
					vprint "STEEL|SLiM/lib?(): ERROR!! lib file must specify a 'slim-version:"
				]
			][
				vprint "STEEL|SLiM/lib?(): ERROR!! supplied lib file has no header!"
			]
		][
			vprint "STEEL|SLiM/lib?(): ERROR!! supplied data is not an object!"
		]
		return false
	]
	
	
	
	;----------------
	;-    CACHE
	;----
	CACHE: func [
{
		copy the new library in the libs list.
		NOTE that the current library will be replaced if one is already present. but
		any library pointing to the old version still points to it.
}
		lib "Library module to cache."
		/remove "Removes the lib from cache"
		/local ptr
	][
		either lib? lib [
			either remove [
				if ( cached? lib/header/slim-name )[
					system/words/remove/part find libs lib/header/slim-name 2
				]
			][
				if ( cached? lib/header/slim-name )[
					vprint rejoin [{STEEL|SLiM/cache()  replacing module: "} uppercase to-string lib/header/slim-name {"}]
					; if the library was cached, then remove it from libs block
					system/words/remove/part find libs lib/header/slim-name 2
				]
				;---
				; actually add the library in the list...
				vprint rejoin [{STEEL|SLiM/cache() registering module: "} uppercase to-string lib/header/slim-name {"}]
				insert tail libs lib/header/slim-name
				insert tail libs lib
			]
		][
			vprint "STEEL|SLiM/cache(): ERROR!! supplied argument is not a library object!"
		]
	]




	;----------------
	;-    CACHED?
	;----
	; find the pointer to an already opened library object 
	;  a return of none, means that a library of that name was not yet registered...
	;
	; file! type added to support file-based lib-name
	;----
	CACHED?: function [libname [word! file!] /list][lib libs libctx][
		either list [
			libs: copy []
			foreach [lib libctx] self/libs [
				append libs lib
			]	
			libs
		][	
			lib: select self/libs libname
			;vprint [{STEEL|SLiM/cached? '} uppercase to-string libname {... } either lib [ true][false]]
		]
		;return lib
	]


	;----------------
	;-    LIST
	;----
	; find the pointer to an already opened library object 
	;  a return of none, means that a library of that name was not yet registered...
	;----
	LIST: has [lib libs libctx][
		libs: copy []
		foreach [lib libctx] self/libs [
			append libs lib
		]	
		libs
	]



	;----------------
	;-    ABSPATH()
	;----
	; return a COPY of path + filename
	;----
	abspath: func [path file][
		append copy path file
	]



	;----------------
	;-    FIND-PATH()
	;----
	; finds the first occurence of file in all paths.
	; if the file does not exist, it checks in urls and if it finds it there, 
	; then it calls the download method.  And returns the path returned by download ()
	; /next switch will attempt to find occurence of file when /next is used, file actually is a filepath.
	;----
	find-path: func [
		file
		/next prevpath
		/lib
		/local path item paths disk-paths
	][
		vin ["SLiM/find-path(" file ")"]
		
		if next [
			vprint/error "SLiM/find-path() /next refinement not yet supported"
		]
		
		
		; usefull setup which allows slim-relative configuration setup file. (idea and first example provided by Robert M. Muench)
	     disk-paths: either (exists? join slim-path %slim-paths.r) [
	    	reduce load join slim-path %slim-paths.r
	    ][
	    	[]
	    ]

		; variety of methods to have slim running without even having to setup slim/paths explicitely!
		paths: copy []
		
		v?? slim-path
		
		foreach path reduce [ what-dir (join what-dir %libs/) self/paths disk-paths self/slim-path] [	
			append paths path 
		]
		

		v?? paths
			
		
		foreach item paths [
			vprint item
			if file! = type? item[
				path: abspath item file
				either exists? path [
					either lib [
						data: load/header/all lib-file
						;probe first first data
						either (in data 'slim-name ) [
							break
						][
							path: none
						]
					][
						break
					]
				][
					path: none
				]
			]
		]
		
		vprint path
		vout
		return path
	]
	

	
	
	
	;----------------
	;-    VALIDATE()
	;----
	;----
	VALIDATE: function [header][pkg-blk package-success][
		vprint/in ["SLiM/validate() ["]
		success: false
		ver: system/version
		
		;probe ver
		;probe self/open-version
		
		;strip OS related version
		ver: to-tuple reduce [ver/1 ver/2 ver/3]
		; make sure the lib is sufficiently recent enough
		either(version-check header/version self/open-version "+") [
			;print "."
			; make sure rebol is sufficient
			either all [(in header 'slim-requires) header/slim-requires ] [
				pkg-blk: first next find header/slim-requires 'package
				either pkg-blk [
					foreach [package version] pkg-blk [
						package: to-string package
						;probe package
						if find package to-string system/product [
							;print "library validation was successfull"
							success: version-check ver version package
							package-success: true
							break
						]
					]
					if not success [
						either package-success [
							vprint "SLiM/validate() rebol version mismatch"
						][
							vprint "SLiM/validate() rebol package mismatch"
						]
					]
				][
					; library does not impose rebol version requisites
					; it should thus work with ALL rebol versions.
					success: true
				]
			][
				success: true
			]
		][
			vprint ["SLiM/validate() LIBRARY VERSION mismatch... needs v" self/open-version "   Found: v"header/version]
		]
		vprint/out "]"
		success
	]
	
	
	
	;-------------------
	;-    AS-TUPLE()
	;-------------------
	; enforces any integer or decimal as a 3 digit tuple value (extra digits are ignored... to facilitate rebol version matching)
	; now also allows you to truncate the number of digits in a tuple value... usefull to compare major versions,
	; or removing platform part of rebol version.
	;----
	as-tuple: func [
		value
		/digits dcount
		/local yval i
	][
		value: switch type?/word value [
			none! [0.0.0]
			integer! [to-tuple reduce [value 0 0]]
			decimal! [
				yVal: to-string remainder value 1
				either (length? yVal) > 2 [
					yVal: to-integer at yVal 3
				][
					yVal: 0
				]
				
				to-tuple reduce [(to-integer value)   yVal   0 ]
			]
			tuple! [
				if digits [
					if (length? value) > dcount [
						digits: copy "" ; just reusing mem space... ugly
						repeat i dcount [
							append digits reduce [to-string pick value i "."]
						]
						digits: head remove back tail digits
						value: to-tuple digits
					]
				]
				value
			]
		]
		value
	]

	
	
	;----------------
	;-    VERSION-CHECK()
	;----
	; mode's last character determines validitiy of match.
	;----
	version-check: func [supplied required mode][
		supplied: as-tuple supplied
		required: as-tuple required
		
		;vprobe supplied
		;vprobe required
		
		any [
			all [(#"=" = (last mode)) (supplied = required)]
			all [(#"-" = (last mode)) ( supplied <= required)]
			all [(#"_" = (last mode)) ( supplied < required)]
			all [supplied >= required]
			;all [(#"+" = (last mode)) ( supplied >= required)]
		]
	]



	;----------------
	;-    EXPOSE()
	;----
	; expose words in the global namespace, so that you do not have to use a lib ptr.
	; context is left untouched, so method internals continue to use library object's
	; properties.
	;----------------
	expose: func [
		lib [word! string! object!]
		words [word! block! none!]
		/prefix pword
		/local reserved-words word rwords rsource rdest blk
	][
		vprint/in "SLiM/EXPOSE() ["
		
		; handle alternate lib argument datatypes
		if string? lib [lib: to-word lib]
		if word? lib [lib: cached? lib]
		
		
		; make sure we have a lib object at this point
		if lib? lib [
			
			reserved-words: [--init-- 
				;load save read write 
				self rsrc-path header --private--]
			if in lib '--private-- [
				vprint "ADDING PRIVATE WORDS"
				reserved-words: append copy reserved-words lib/--private--
			]
			vprobe reserved-words
				
			;----------------------------
			;----- SELECT WORDS TO EXPOSE
			;----------------------------
			;special case: 'all should expose all words...
			if words = 'all [words: none]
			
			; make sure we have a block of words to work with
			switch type?/word words [
				block! [
					;---------------------------------------------
					; find, set and remove a rename block, if any.
					if (rwords: find words block!) [
						blk: first rwords
						remove rwords
						rwords: blk
					]
					
					either (  ('none = first words) OR (none = first words) )[
						words: copy first lib
					][
						if 0 = length? words [ words: copy first lib ]
					]
				]
				; expose only one word
				word! [
					words:  make block! reduce [words]
				]
				
				; expose all the lib's words
				none! [ words: copy first lib ]
			]

			
			;----------------------------
			;----- SELECT PREFIX TO USE
			;----------------------------
			if not prefix [
				; has the library creator set a default prefix?
				either in lib/header 'slim-prefix [
					pword: lib/header/slim-prefix
				][
					pword: lib/header/slim-name
				]
			]
			
			;----------------------------
			;----- BUILD EXPOSE LIST
			;----------------------------
			; create base expose list based on rename words list
			either not rwords [
				rwords: copy []
			][
				if odd? (length? rwords) [
					vprint/error ",--------------------------------------------------------."
					vprint/error "|  SLiM/EXPOSE() ERROR!!:                                |"
					vprint/error "|                                                        |"
					vprint/error head change at "|                                                        |"  7 (rejoin ["module: "lib/header/slim-name ])
					vprint/error "|     invalid rename block has an odd number of entries  |"
					vprint/error "|     Rename block will be ignored                       |"
					vprint/error "`--------------------------------------------------------'"
					rwords: copy []
				]
			]
			
			
			;add all other words which should keep their names      
			foreach word words [
				insert/dup tail rwords word 2
			]
			;----------------------------
			;----- REMOVE ANY RESERVED WORDS FROM LIST!
			;----------------------------
			expose-words: make block! (length? rwords)
			expose-list: make block! ((length? rwords) / 2)
			forall rwords [
				worda: to-word first rwords
				wordb: second rwords
				
				; remove the word if its a reserved word
				if not (find reserved-words wordb) [
					;remove the word if its already in the list
					if not (find expose-list wordb)[
						insert tail expose-words worda
						insert tail expose-words wordb
						insert tail expose-list wordb
					]
				]
				
				rwords: next rwords
			]
			

			
			;----------------------------
			;----- EXPOSE WORDS IN GLOBAL CONTEXT
			;----------------------------
			forall expose-words [
				either pword [
					worda: to-word rejoin [to-string pword "-" to-string first expose-words]
				][
					worda: to-word first expose-words
				]
				wordb: second expose-words
				set worda get in lib wordb
				expose-words: next expose-words
				vprint ["exposing: " wordb " as " worda]
			]
		]
		vprint/out "]"
	]
	
	
	
	
	;----------------
	;-    ENCOMPASS()
	;----
	;----
	encompass: function [
		func-name [word!]
		/args opt-args [block!]
		/pre pre-process
		/post post-process
		/silent
	][
		blk dt func-args func-ptr func-body last-ref item params-blk refinements word arguments args-blk
	][
		func-ptr: get in system/words func-name
		if not any-function? :func-ptr [vprint/error "  error... funcptr is not a function value or word" return none]
		arguments: third :func-ptr 
		func-args: copy []
		last-ref: none
		args-blk: copy compose [([('system)])([('words)])(to paren! to-lit-word func-name)]
		params-blk: copy [] ; stores all info about the params
		FOREACH item arguments [
			SWITCH/default TYPE?/word item [
				block! [
					blk: copy []
					FOREACH dt item [
						word: MOLD dt
						APPEND blk TO-WORD word
					]
					APPEND/only func-args blk
				]
				refinement! [
					last-ref: item
					if last-ref <> /local [
						APPEND func-args item
						append/only args-blk to paren! compose/deep [either (to-word item) [(to-lit-word item)][]]
					]
				]
				word! [
					either last-ref [
						if last-ref <> /local [
							append/only params-blk to paren! copy compose/deep [either (to-word last-ref) [(item)][]]
							append func-args item
						]
					][
						append/only params-blk to paren! item
						append func-args item
					]
				]
			][append/only func-args item]
		]
		
		blk: append append/only copy [] to paren! compose/deep [ to-path compose [(args-blk)]] params-blk
		func-body: append copy [] compose [
			(either pre [pre-process][])
			enclosed-func: compose (append/only copy [] blk)
			(either silent [[
				if error? (set/any 'encompass-err try [do enclosed-func]) [return :encompass-err]]
			][
				[if error? (set/any 'encompass-err try [set/any 'rval do enclosed-func]) [return :encompass-err]]
			])
			
			(either post [post-process][])
			return rval
		]
		;print "------------ slim/encompass debug --------------"
		;probe func-body
		;print "------------------------------------------------^/^/"
		if args [
			refinements: find func-args refinement!
			either refinements[
				func-args: refinements
			][
				func-args: tail func-args
			]
			insert func-args opt-args
		]
		append func-args [/rval /encompass-err]
		func-args: head func-args
		return func func-args func-body
	]
]
;- SLIM / END


slim/linked-libs: []


;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: GLASS-LIBS  v1.0.0
;--------------------------------------------------------------------------------

append slim/linked-libs 'glass-libs
append/only slim/linked-libs [


;--------
;-   MODULE CODE


slim/register/header [
	bulk: 					bulk-lib: 					slim/open 'bulk none
	configurator: 			configurator-lib: 			slim/open 'configurator none
	epoxy: 					epoxy-lib: 					slim/open 'epoxy none
	event: 					event-lib: 					slim/open 'event none
	frame: 					frame-lib: 					slim/open 'frame none
	gl: glass: gl-lib: 		glass-lib: 					slim/open 'glass none
	glaze: 					glaze-lib: 					slim/open 'glaze none
	glob: 					glob-lib: 					slim/open 'glob none
	glue: 					glue-lib: 					slim/open 'glue none
	group: 					group-lib: 					slim/open 'group none
	icons: 					icons-lib: 					slim/open 'icons none
	liquid: 				liquid-lib: 				slim/open 'liquid none
	marble: 				marble-lib: 				slim/open 'marble none
	pane: 					pane-lib: 					slim/open 'pane none
	popup: 					popup-lib: 					slim/open 'popup none
	requestor: 				requestor-lib: 				slim/open 'requestor none
	scroll-frame: 			scroll-frame-lib: 			slim/open 'scroll-frame none
	sillica: 				sillica-lib: 				slim/open 'sillica none
	
	
	scrolled-list:	group-scrolled-list:	group-scrolled-list-lib:	slim/open 'group-scrolled-list none
	button: 		button-lib: 			style-button-lib: 			slim/open 'style-button none
	choice: 		choice-lib: 			style-choice-lib: 			slim/open 'style-choice none
	droplist: 		droplist-lib: 			style-droplist-lib: 		slim/open 'style-droplist none
	field: 			field-lib: 				style-field-lib: 			slim/open 'style-field none
	icon-button: 	icon-button-lib:		style-icon-button-lib: 		slim/open 'style-icon-button none
	list: 			list-lib: 				style-list-lib: 			slim/open 'style-list none
	progress: 		progress-lib: 			style-progress-lib: 		slim/open 'style-progress none
	script-editor: 	script-editor-lib:	 	style-script-editor-lib:	slim/open 'style-script-editor none
	scroller: 		scroller-lib: 			style-scroller-lib: 		slim/open 'style-scroller none
	toggle: 		toggle-lib: 			style-toggle-lib: 			slim/open 'style-toggle none
		
	
	viewport: 		viewport-lib: 	slim/open 'viewport none
	window: 		window-lib: 	slim/open 'window   none
	
	utils: 			utils-lib:		slim/open 'utils    none
	
	
	;-----------------------------------------------
	; these will be added in a future distribution.
	;-----------------------------------------------
	;compiler: compiler-lib: slim/open 'compiler none
	;style-glare-label: style-lib: slim/open 'style none
	;glare: glare-lib: slim/open 'glare none
	
	
]




;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %glass-libs.r 
    date: 31-Jan-2011 
    version: 1.0.0 
    slim-name: 'glass-libs 
    slim-prefix: none 
    slim-version: 0.9.14 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: GLASS-LIBS
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: BULK  v0.9.4
;--------------------------------------------------------------------------------

append slim/linked-libs 'bulk
append/only slim/linked-libs [


;--------
;-   MODULE CODE




slim/register/header [
	;- FUNCTIONS
	
	all*: :all
	
	;-----------------
	;-     is-bulk?
	;
	; returns true if data complies to all required bulk prerequisites (including type)
	;-----------------
	set 'is-bulk? func [
		blk 
		/header "Only verify header, content might not match columns number"
		/local cols
	][
		all [
			block? blk
			integer? cols: get-bulk-property blk 'columns
			any [
				header
				0 = mod ((length? blk) - 1) cols
			]
		]
	]
	
	
	;-----------------
	;-     symmetric-bulks?()
	;
	; returns true if both bulks are of same shape.
	;
	; currently this only makes sure both bulks have the same number of columns.
	; eventually, if the bulks have column labels, they should be in the same order.
	;-----------------
	set 'symmetric-bulks? func [
		blk [block!]
		blk2 [block!]
		/strict "this will trigger a stricter verification (undefined for now)"
	][
		(bulk-columns blk) = (bulk-columns blk2)
	]
	
	
	
	
	;-----------------
	;-     get-bulk-property
	;-----------------
	set 'get-bulk-property func [
		blk [block!]
		prop [word! lit-word! set-word!]
		/index "return the index of the property set-word: instead of its value"
		/block "return the header at position of property instead of its value"
		/local hdr item
	][
		all [
			block? hdr: pick blk 1
			hdr: find hdr to-set-word prop
			any [
				all [index index? hdr]
				all [block hdr]
				all [
					not set-word? item: pick hdr 2
					item
				]
			]
		]
	]
	
	
	;-----------------
	;-     get-bulk-label-column()
	;
	; returns an integer which identifies what is the label column for this bulk, if any
	; returns none if none is defined.
	;-----------------
	set 'get-bulk-label-column func [
		blk [block!]
		/local col
	][
		if col: get-bulk-property 'label-column [
			any [
				all [
					integer? col
					col
				]
				; resolve it from labels
				all [
					word? col
					integer? col: get-bulk-labels-index blk col
					col
				]
			]
		]
	]
	
	
	;-----------------
	;-     get-bulk-labels-index()
	;
	; if columns are labeled, return the column index matching specified bulk
	; returns none if no labels or name not in list.
	;-----------------
	set 'get-bulk-labels-index func [
		blk [block!]
		label [word!]
		/local labels
	][
		if block? labels: get-bulk-property 'labels [
			if labels: find labels label [
				index? labels
			]
		]
	]
	
	
	
	
	;-----------------
	;-     set-bulk-property()
	;-----------------
	set 'set-bulk-property func [
		blk [block!]
		prop [word! set-word! lit-word!]
		value
		/local hdr
	][
		prop: to-set-word prop
		if set-word? value [
			to-error "set-bulk-property(): cannot set property as set-word type"
		]
		; property exists, replace value
		either hdr: get-bulk-property/block blk prop [
			insert next hdr value
		][
			; new property
			append first blk reduce [to-set-word prop value]
		]
		value
	]
	
	
	;-----------------
	;-     set-bulk-properties()
	;-----------------
	set 'set-bulk-properties func [
		blk [block!]
		props [block!]
		/local property value
	][
		until [
			property: pick props 1
			props: next props
			if set-word? :property [
				value: pick props 1
				; we totally ignore unspecified properties
				unless set-word? :value [
					props: next props
					set-bulk-property blk property value
				]
			]
			tail? props
		]
	]
	
	
	
	
	;-----------------
	;-     bulk-find-same()
	;-----------------
	set 'bulk-find-same func [
		series [block!] "note this is not a bulk input but an arbitrary series type"
		item [series! none! ]
		/local s 
	][
		unless none? item [
			while [s: find series item] [
				if same? first s item [return  s]
				series: next s
			]
		]
		none
	]
	
	
	;-----------------
	;-     search-bulk-column()
	;
	; <to do> replace the search mechanism by my profiled fast-find() algorithm on altme.
	;-----------------
	set 'search-bulk-column func [
		blk [block!]
		column [word! integer!] "if its a word, it will get the column from that property (which must exist and be an integer)"
		value
		/same "series must be the exact same value, not a mere equality"
		/row "return row instead of row index"
		/all "value is a block of items to search, output is put in a block."
		/local data columns rdata index
	][
		vin [{search-bulk-column()}]

		column: bulk-column-index blk column

		; generate search index		
		index: extract at next blk column columns
		
		; perform search 
		
		either all [
			; in this mode, we find ALL occurrences which match input, even if they occur more than once
			
			rdata: copy []
			foreach item value [
				until [
					; in this mode, we return the FIRST item found only.
					either  all* [
						same
						series? value
					][
						data: bulk-find-same index item
					][
						data: find index item
					]
					
					not if data [
						either row [
							append/only rdata get-bulk-row blk index? data
						][
							append/only rdata index? data
						]
					]
				]
			]
			data: rdata
		][
			; in this mode, we return the FIRST item found only.
			either  all* [
				same
				series? value
			][
				data: bulk-find-same index value
			][
				data: find index value
			]
			
			if data [
				either row [
					data: get-bulk-row blk index? data
				][
					data: index? data
				]
			]	
		]
		vout
		index: rdata: value: blk: none
		data
	]
	
	
	;-----------------
	;-     bulk-column-index()
	;-----------------
	bulk-column-index: func [
		blk [block!]
		column [integer! word! none!]
		/default col [integer!] "If column is a word and property doesn't exist, use this column by default. Normally, we would raise an error."
		/local colname
	][
		vin [{bulk-column-index()}]
		colname: column
		case [
			none? column [
				column: 1
			]
		
			word? column [
				column: get-bulk-property blk column
				v?? column
				v?? default
				v?? col
				either all [
					none? column
					default
				][
					column: col
				][
					if none? column [
						to-error rejoin ["BULK/bulk-column-index(): specified column name (" colname ") doesn't exist or is none"]
					]
					unless integer? column [
						to-error ["BULK/bulk-column-index(): specified column (" colname ") does not equate to an integer value"]
					]
				]
			]
		]
		
		if column > bulk-columns blk [
			to-error rejoin ["BULK/bulk-column-index(): column index cannot be larger than number of columns in bulk: " column]
		]	

		vout
		column
	]
	
	
	
	;-----------------
	;-     filter-bulk()
	; 
	; takes a bulk, returns a copy with items left-out so only a subset is left.
	;
	; the mode is only to allow eventual different filtering algorithms.
	;-----------------
	set 'filter-bulk func [
		blk [block!]
		mode [word!] ; currently supports ['simple | 'same], expects [column: [integer! word! none!] filter: [any!]]
		spec [block!]
		/local filter column columns out data
	][
		vin [{filter-bulk()}]
		columns: bulk-columns blK
		v?? mode
		switch/default mode [
			simple [
				either all [
					2 = length? spec
					integer? column: bulk-column-index/default blk first spec 1
				][
					filter: second spec
					either any [
						filter = ""
						filter = none
					][
						; this means don't filter anything (keep all).
						; we still return a copy
						out: copy-bulk blk
					][
						out: make block! length? blk
						out: insert/only out copy first blk
						
						; skip properties
						blk: next blk
						until [
							either series? data: pick blk column [
								if find data :filter [
									out: insert out copy/part blk columns
								]
							][
								if :data = :filter [
									out: insert out copy/part blk columns
								]
							]
							empty? blk: skip blk columns
						]
					]
				][
					to-error rejoin ["bulk.r/filter-bulk(): invalid spec: " mold/all spec "'"]
				]
			]
			same [
				; the spec will be a list of labels to extract from the supplied bulk
				; the strings have to be the very same string, not mere textual equivalents.
				;
				; this allows a bulk with similar, but different strings to return only
				; those which are explicitely specified in the block, even if they have the same
				; text.
				;
				; the bulk may contain a property called 'label-column and it MUST be within
				; columns bounds.  Otherwise, the first column is used by default.
				
				column: bulk-column-index/default blk 'label-column 1
				
				out: make block! length? blk
				out: insert/only out copy first blk
				
				; skip properties
				blk: next blk
				until [
					;print ""
					either series? data: pick blk column [
						;v?? data
						;v?? spec
						if bulk-find-same :spec data [
							out: insert out copy/part blk columns
						]
					][
						if :data = :spec [
							out: insert out copy/part blk columns
						]
					]
					;vprobe find spec data
					empty? blk: skip blk columns
				]
				
			]
		][
			to-error rejoin ["bulk.r/filter-bulk(): Unrecognized filter mode: '" mode "'"]
		]
		vout
		head out
	]
	
	
	
	
	;-----------------
	;-     get-bulk-row()
	;
	; rows cannot be retrieved if index is < 1
	;-----------------
	set 'get-bulk-row func [
		blk [block!]
		row [integer! word!] "Index OR 'last"
		/local cols 
	][
		cols: get-bulk-property blk 'columns
		
		row: switch/default row [
			last [
				;probe "LAST BULK!"
				row: bulk-rows blk
			]
		][row]
		
		all [
			integer? row 
			row > 0
			row: copy/part at blk (row - 1 * cols + 2) cols
			not empty? row
			row
		]
	]
	
	
	;-----------------
	;-     bulk-columns()
	;-----------------
	set 'bulk-columns func [
		blk [block!]
	][
		get-bulk-property blk 'columns
	]
	
	
	
	
	;-----------------
	;-     bulk-rows()
	;-----------------
	set 'bulk-rows func [
		blk [block!]
		/local cols
	][
		vin [{bulk-rows()}]
		cols: get-bulk-property blk 'columns
		;v?? blk
		;v?? cols
		cols: to-integer ((length? next blk) / cols)
		vout
		cols
	]
	
	
	;-----------------
	;-     copy-bulk()
	;
	; makes a shallow copy of block, with an independent properties header.
	;-----------------
	set 'copy-bulk func [
		blk [block!]
	][
		vin [{copy-bulk()}]
		blk: copy blk
		blk/1: copy blk/1
		vout
		blk
	]
	
	
	;-----------------
	;-     sort-bulk()
	;-----------------
	set 'sort-bulk func [
		blk [block!]
		/using sort-column [integer! word! none!] "what column to sort on, none defaults to 'sort-column property or first column if undefined."
	][
		sort-column: any [
			any [
				all [
					integer? sort-column
					sort-column
				]
				; get the sort column from a property in the bulk.
				all [
					word? sort-column
					integer? sort-column: get-bulk-property sort-column
					sort-column
				]
			]
			
			; get the sort column from a property in the bulk.
			all [
				integer? sort-column: get-bulk-property 'sort-column
				sort-column
			]
			
			; default 
			1
		]
		sort/skip/compare blk (bulk-columns blk) sort-column
		blk
	]
	
	
	
	
	
	
	;-----------------
	;-     insert-bulk-records()
	;-----------------
	set 'insert-bulk-records func [
		blk [block!]
		records [block!]
		row [integer! none!]
		/local cols
	][
		cols: get-bulk-property blk 'columns
		either 0 = mod (length? records) cols [
			either row [
				insert at blk (cols - 1 * row + 1) records
			][
				insert tail blk records
			]
	
			; makes probing much easier to analyse
			new-line at head blk 2 true
			new-line/skip next head blk true cols
		][
			to-error "insert-bulk-row(): record length(s) doesn't match bulk record size."
		]
	]
	
	
	;-----------------
	;-     add-bulk-records()
	;-----------------
	set 'add-bulk-records func [
		blk [block!]
		records [block!]
	][
		insert-bulk-records blk records none
	]
	
	
	
	
	;-----------------
	;-     make-bulk()
	;-----------------
	set 'make-bulk func [
		columns
		/records data [block!]
		/properties props [block!]
		/local blk
	][
		blk: compose/deep [[columns: (columns)]]
		if records [
			insert-bulk-records blk data none
		]
		if properties [
			set-bulk-properties blk props
		]
		blk
	]
	
	;-----------------
	;-     clear-bulk()
	;
	; removes all the records from a bulk, but doesn't change header.
	;-----------------
	set 'clear-bulk func [
		blk [block!]
	][
		vin [{clear-bulk()}]
		either is-bulk? blk [
			clear at blk 2
		][
			to-error "clear-bulk(): supplied data isn't a valid Bulk block!"
		]
		vout
	]
	
]







;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %bulk.r 
    date: 15-Jun-2010 
    version: 0.9.4 
    slim-name: 'bulk 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: BULK
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: CONFIGURATOR  v0.2.13
;--------------------------------------------------------------------------------

append slim/linked-libs 'configurator
append/only slim/linked-libs [


;--------
;-   MODULE CODE


slim/register/header [
	;print "... DISTRO CONFIGURATOR LOADED"
	utils: slim/open 'utils none
	
	*copy: get in system/words 'copy
	*mold: get in system/words 'mold
	*get: get in system/words 'get
	*probe: get in system/words 'probe
	
	whitespace: charset "^/^- "

	;- !CONFIG []
	; note that tags surrounded by '--' (--tag--) aren't meant to be substituted within the apply command.
	!config: context [
		;- INTERNALS
		
		;-    store-path:
		store-path: none

		
		;-    app-label:
		; use this in output related strings like when storing to disk
		app-label: none
		
		
		;-------------------------------
		;-    -- object-based internals
		;-    tags:
		; a context of values 
		tags: none
		
		
		;-    save-point:
		; a save point of tags which can be restored later
		; NOTE: saves only the tags (on purpose).
		save-point: none
		
		
		;-    dynamic:
		; this is a list of tags which are only use when apply is called, they are in fact driven
		; by a function, cannot be set, but can be get.  are not part of any other aspect of configurator
		; like disk, copy, backup, etc.
		;
		; clone will duplicate the dynamic tags to the new !config
		dynamic: none
		
		
		
		;-    defaults:
		; a save point which can only every be set once, includes concealed tags.
		; use snapshot-defaults() to set defaults.
		; use reset() to go back to these values
		;
		; NOTE: saves only the tags (on purpose).
		defaults: none
		
		;-    docs:
		; any tags in this list can be called upon for documentation
		;
		; various functions may include these help strings (mold, probe, etc)
		docs: none
		
		;-    types:
		; some tags might require to be bound to specific datatypes.
		; this is usefull for storage and reloading... enforcing integrity of disk-loaded configs.
		types: none
		
		
		;-------------------------------
		;-    -- block-based internals
		;-    protected:
		; tags which cannot be overidden.
		protected: none
		
		
		;-    concealed:
		; tags which aren't probed saved or loaded
		concealed: none
		
		
		
		;-    space-filled:
		; tags which cannot *EVER* contain whitespaces.
		space-filled: none
		
		
		
		;-  
		;- METHODS
		
		;-----------------
		;-    protect()
		;-----------------
		protect: func [
			tags [word! block!]
			/local tag
		][
			vin [{!config/protect()}]
			
			tags: compose [(tags)]
			foreach tag tags [
				vprint join "protecting: " tag
				; only append if its not already there
				any [
					find protected tag
					append protected tag
				]
			]
			tags: tag: none
			vout
		]
		
		
		;-----------------
		;-    protected?()
		;-----------------
		protected?: func [
			tag [word!]
		][
			vin [{!config/protected?()}]
			vprobe tag
			vout/return
			vprobe found? find protected tag
		]
		
		
		;-----------------
		;-    conceal()
		;-----------------
		conceal: func [
			tags [word! block!]
			/local tag
		][
			vin [{!config/conceal()}]
			
			tags: compose [(tags)]
			foreach tag tags [
				vprint rejoin ["concealing: " tag]
				; only append if its not already there
				any [
					find concealed tag
					append concealed tag
				]
			]
			tags: tag: none
			vout
		]
		
		
		;-----------------
		;-    concealed?()
		;-----------------
		concealed?: func [
			tag [word!]
		][
			vin [{!config/concealed?()}]
			vprobe tag
			vout/return
			vprobe found? find self/concealed tag
		]
		
		
		;-----------------
		;-    cast()
		;-----------------
		; force !config to fit tags within specific datatype
		;-----------------
		cast: func [
			tag [word!]
			type [word! block!] "note these are pseudo types, starting with the ! (ex !state) not actual datatype! "
		][
			vin [{!config/cast()}]
			unless set? tag [
				to-error rejoin ["!config/cast(): tag '" tag " doesn't exist in config, cannot cast it to a datatype"]
			]
			type: compose [(type)]
			types: make types reduce [to-lit-word tag type]
			vout
		]
		
		
		
		;-----------------
		;-    typed?()
		;-----------------
		; is this tag currently type cast?
		;-----------------
		typed?: func [
			tag [word!]
		][
			vin [{!config/typed?()}]
			found? in types tag
			vout
		]
		
		
		;-----------------
		;-    proper-type?()
		;-----------------
		; if tag currently typed?, verify it.  Otherwise return true.
		;-----------------
		proper-type?: func [
			tag [word!]
			/value val
		][
			vin [{!config/proper-type?()}]
			val: either value [val][get tag]
			any [
				all [typed? tag find types type?/word val ]
				true
			]
			vout
		]
		
		
		
		
		;-----------------
		;-    fill-spaces()
		;-----------------
		; prevent this tag from ever containing any whitespaces.
		;-----------------
		fill-spaces: func [
			tag [word!]
		][
			vin [{!config/fill-spaces()}]
			unless find space-filled tag [
				append space-filled tag
				; its possible to call this before even adding tag to config
				if set? tag [
					set tag tags/:tag ; this will enfore fill-space right now
				]
			]
			vout
		]
		
		;-----------------
		;-    space-filled?()
		;-----------------
		space-filled?: func [
			tag [word!]
		][
			vin [{!config/space-filled?()}]
			vprint tag
			vprobe tag: found? find space-filled tag
			vout
			tag
		]
		
		
		
		;-----------------
		;-    set()
		;
		; set a tag value, add the tag if its not yet there.
		;
		; ignored if the tag is protected.
		;-----------------
		set: func [
			tag [word!]
			value
			/type types [word! block!] "immediately cast the tag to some type"
			/doc docstr [string!] "immediately set the help for this tag"
			/overide "ignores protection, only for use within distrobot... code using the !config should not have acces to this."
			/conceal "immediately call conceal on the tag"
			/protect "immediately call protect on the tag"
			/local here
		][
			vin [{!config/set()}]
			vprobe tag
			
			
			either all [not overide protected? tag] [
				; <TODO> REPORT ERROR
				vprint/error rejoin ["CANNOT SET CONFIG: <" tag "> IS protected"]
			][
				either function? :value [
					; this is a dynamic tag, its evaluated, not stored.
					dynamic: make dynamic reduce [to-set-word tag none ]
					dynamic/:tag: :value
				][
					any [
						in tags tag
						;tags: make tags reduce [load rejoin ["[ " tag ": none ]"]
						tags: make tags reduce [to-set-word tag none ]
					]
					if space-filled? tag [
						value: to-string value
						parse/all value [any [ [here: whitespace ( change here "-")] | skip ] ]
					]
					
					;v?? tags
					tags/:tag: :value
				]
			]
			if conceal [
				self/conceal tag
			]
			
			if protect [
				self/protect tag
			]
			
			if doc [
				document tag docstr
			]
			
			if type [
				cast tag types
			]
			
			vout
			value
		]
		
		
		;-----------------
		;-    set?()
		;-----------------
		set?: func [
			tag [word!]
		][
			vin [{!config/set?()}]
			vprobe tag
			vout
			found? in tags tag
		]
		
		
		;-----------------
		;-    document()
		;-----------------
		document: func [
			tag [word!]
			doc [string!]
		][
			vin [{!config/document()}]
			vprobe tag
			unless set? tag [
				to-error rejoin ["!config/document(): tag '" tag " doesn't exist in config, cannot set its document string"]
			]
			docs: make docs reduce [to-set-word tag doc]
			vout
		]
		
		
		;-----------------
		;-    help()
		;-----------------
		help: func [
			tag [word!]
		][
			vin [{!config/help()}]
			vprobe tag
			vout
			*get in docs tag
		]
		
		
		
		
		;-----------------
		;-    get()
		;-----------------
		get: func [
			tag [word!]
		][
			vin [{!config/get()}]
			vprobe tag
			vout
			either (in dynamic tag) [
				dynamic/:tag
			][
				*get in tags tag
			]
		]
		
		
		
		
		;-----------------
		;-    apply()
		;
		; <TODO> make function recursive
		;-----------------
		apply: func [
			data [string! file! word!] ; eventually support other types?
			/only this [word! block!] "only apply one or a set of specific configs"
			/reduce "Applies config to some config item"
			/file "corrects applied data so that file paths are corrected"
			/local tag lbl tmp
		][
			vin [{!config/apply()}]

			; loads the tag, if reduce is specified, or uses the data directly
			data: any [all [reduce tags/:data] data]
			
			v?? data
			
			this: any [
				all [
					only 
					compose [(this)]
				]
				self/list/dynamic
			]
			
			foreach tag this [
				lbl: to-string tag
				; don't apply the tag to itself, if reduce is used!
				unless all [reduce tag = data][
					; skip internal configs
					unless all [lbl/1 = #"-" lbl/2 = #"-"] [
						tmp: get tag
						;print "#####"
						;?? tmp
						;print ""
						replace/all data rejoin ["<" lbl ">"] to-string tmp
					]
				]
			]
			vout
			if file [
				tmp: utils/as-file *copy data
				clear head data
				append data tmp
			]
			data
		]
		
		
		;-----------------
		;-    copy()
		;-----------------
		; create or resets a tag out of another
		;-----------------
		copy: func [
			from [word!]
			to [word!]
		][
			vin [{!config/copy()}]
			set to get from
			vout
		]
		
		
		;-----------------
		;-    as-file()
		;-----------------
		; convert a tag to a rebol file! type
		;
		; OS or rebol type paths, as well as string or file are valid as current tag data.
		;-----------------
		as-file: func [
			tag [word!]
			/local value
		][
			vin [{as-file()}]
			set tag value: utils/as-file get tag
			vout
			value
		]
		
		
		
		
		;-----------------
		;-    clone()
		;-----------------
		; take a !config and create a deep copy of it
		;-----------------
		clone: func [][
			vin [{!config/clone()}]
			vout
			make self [
				tags: make tags []
				types: make types []
				docs: make docs []
				dynamic: make dynamic []
				
				if defaults [
					defaults: make defaults []
				]
				
				if save-point [
					save-point: make save-point []
				]
				
				; series copying is intrinsic to make object. 
				;  protected 
				;  error-modes
				; space-filled
			]
		]
		
		;-----------------
		;-    backup()
		;-----------------
		; puts a copy of current tags info in store-point.
		;-----------------
		backup: func [
		][
			vin [{!config/backup()}]
			save-point: make tags []
			vout
		]
		
		
		
		;-----------------
		;-    restore()
		;-----------------
		; restore the tags to an earlier or default state 
		;
		; not
		;
		; NB: -the tags are copied from the reference state... the tags object
		;      itself is NOT replaced.
		;     -if a ref-tags is used and it has new unknown tags, they are ignored
		;
		; WARNING: when called, we LOOSE current tags data
		;
		; <TODO>: enforce types?.  In the meanwhile, we silently use the ref-tags directly.
		;-----------------
		restore: func [
			/visible "do not restore concealed values."
			/safe "do not restore protected values."
			/reset "restore to defaults instead of save-point,  WARNING!!: also clears save-point."
			/using ref-tags [object!] "Manually supply a set of tags to use... mutually exclusive to /reset, this one has more strength."
			/create "new tags should be created from ref-tags."
			/keep-unrefered "Any tags which are missing in ref-tags, default or save point are not cleared."
			/local tag tag-list val ref-words
		][
			vin [{!config/restore()}]
			
			tag-list: list/opt reduce [either visible ['visible][] either safe ['safe][]]
			v?? tag-list
			ref-tags: any[
				ref-tags
				either reset [
					save-point: none
					self/defaults
				][
					save-point
				]
			]
			vprint "restoring to:"
			vprobe ref-tags
			if ref-tags [
				foreach tag any [
					all [create next first ref-tags]
					tag-list
				][
					if any [
						not keep-unrefered
						in ref-tags tag
						create
					][
						set/overide tag *get (in ref-tags tag)
					]
				]
			]
			vout
		]
		
		
		
		
		;-----------------
		;-    delete()
		; remote a tag from configs
		;-----------------
		; <TODO> also remove from other internals: protected, concealed, etc.
		; <TODO> later features might needed to be better reflected in this function
		;-----------------
		delete: func [
			tag [word!]
			/local spec
		][
			vin [{!config/delete()}]
			spec: third tags
			
			if spec: find spec to-set-word tag [
				remove/part  spec 2
				tags: context head spec
			]
			vout
		]
		
		
		;-----------------
		;-    probe()
		;-----------------
		; print a status of the config in console...usefull for debugging
		;-----------------
		probe: func [
			/unsorted
			/full "include document strings in probe"
			/local pt tag v
		][
			vin [{!config/probe()}]
			v: verbose
			verbose: no
			foreach tag any [all [unsorted next first tags] sort next first tags] [
				unless concealed? tag [ 
					either full [
						vprint/always         "+-----------------" 
						vprint/always rejoin ["| " tag ":"]
						vprint/always         "|"
						vprint/always rejoin ["|     " head replace/all any [help tag ""]  "^/" "^/|     "]
						vprint/always         "|"
						vprint/always rejoin ["|     "  *copy/part  replace/all replace/all *mold/all tags/:tag "^/" " " "^-" " " 80]
						vprint/always         "+-----------------" 
					][
						vprint/always rejoin [ utils/fill/with to-string tag 22 "_" ": " *copy/part  replace/all replace/all *mold/all tags/:tag "^/" " " "^-" " " 80]
					]
				]
				;vprint ""
			]
			pt: form protected
			vprint/always ["+-----------------" utils/fill/with "" (1 + (length? pt)) "-" "+"]
			vprint/always ["| Protected tags: " pt " |"]
			vprint/always ["+-----------------" utils/fill/with "" (1 + (length? pt)) "-" "+"]
			verbose: v
			vout
		]
		
		
		;-----------------
		;-    list()
		;-----------------
		; list tags reflecting options.
		;-----------------
		list: func [
			/opt options "supply folowing args using block of options"
			/safe "don't list protected"
			/visible "don't list concealed"
			/dynamic "Also list dynamic"
			/local ignore list
		][
			vin [{!config/list()}]
			
			ignore: clear [] ; reuse the same block everytime.
			
			
			options: any [options []]
			
			if any [
				visible
				find options 'visible
			][
				append ignore concealed
			]
			
			if any [
				safe
				find options 'safe
			][
				append ignore protected
			]
			list: next first tags
			if dynamic [
				append list next first self/dynamic
			]
			vout
			exclude sort list ignore
			
			
		]
		
		
		;-----------------
		;-    mold()
		;-----------------
		; coverts the tags to a reloadable string, excluding any kind of evaluatable code.
		;
		; concealed tags are not part of mold
		;
		; <TODO> make invalid-type recursive in blocks and when /relax is set
		;-----------------
		mold: func [
			/relax "allow dangerous types in mold"
			/using mold-method [function!] "special mold method, we give [tag data] pair to hook, and save out returned data or ignore tag if non is returned"
			/local tag invalid-types val output
		][
			vin [{!config/mold()}]
			output: *copy ""
			invalid-types: any [
				all [relax []]
				[function! object!]
			]
			
			; we don't accumulate concealed tags
			foreach tag list/visible [
				val: get tag
				append output either using [
					vprobe tag
					vprobe mold-method tag val
				][
					
					if find invalid-types type?/word val [
						to-error "!config/mold(): Dangerous datatype not allowed in mold, use /relax if needed"
					]
					rejoin [
						";-----------------------^/"
						"; " head replace/all any [help tag ""]  "^/" "^/; "
						"^/;-----------------------^/"
						tag ": " *mold/all val "^/"
						"^/^/"
					]
				]
			]
			vout
			output
		]
		
		
		
		
		;-----------------
		;-    to-disk()
		;-----------------
		
		to-disk: func [
			/to path [file!]
			/relax
			/only hook [function!] "only same out some of the data, will apply mold-hook, relax MUST also be specified"
			/local tag
		][
			vin [{!config/to-disk()}]
			either path: any [
				path
				store-path
			][
				
				app-label: any [app-label ""]
				
				data: trim rejoin [
					";---------------------------------" newline
					"; " app-label " configuration file" newline
					"; saved: " now/date newline
					"; version: " system/script/header/version newline
					";---------------------------------" newline
					newline
					any [
						all [only relax mold/relax/using :hook]
						all [relax mold/relax]
						mold
					]
				]
					
				
				;vprobe/always data
				
				;v?? path
				
				write path data
			][
				to-error "!CONFIGURATOR/to-disk(): STORE-PATH not set"
			
			]
			vout
		]
		
		
		
		
		;-----------------
		;-    from-disk()
		;-----------------
		; note: any missing tags in disk prefs are fille-in with current values.
		;-----------------
		from-disk: func [
			/from path [file!]
			/create "Create tags comming from disk, dangerous, but usefull when config is used as controlled storage."
		][
			vin [{!config/from-disk()}]
			
			either path: any [
				path
				store-path
			][
				
				; silently ignore missing file
				if exists? path [
					data: construct load path
					;vprobe data
					either create [
						restore/using/keep-unrefered/create data
					][
						restore/using/keep-unrefered data
					]
				]
			][
				to-error "!CONFIGURATOR/from-disk(): STORE-PATH not set"
			]
			
			
			vout
		]
		
		
		;-----------------
		;-    snapshot-defaults()
		;-----------------
		; captures current tags as the defaults.  
		; by default can only be called once.
		;
		; NB: series are NOT shared between tags... so you must NOT rely on config to be the 
		;     exact same? serie, but only an identical one (same value, but different reference).
		;-----------------
		snapshot-defaults: func [
			/overide "allows you to overide defaults if there are any... an unusual procedure"
		][
			vin [{snapshot-defaults()}]
			if any [
				overide
				none? defaults
			][
				defaults: make tags []
			]
			vout
		]
		
		
		
		
		
		;-----------------
		;-    init()
		;-----------------
		init: func [
		][
			vin [{!config/init()}]
			tags: context []
			save-point: none
			defaults: none
			types: context []
			docs: context []
			concealed: *copy []
			protected: *copy []
			space-filled: *copy []
			dynamic: context []
			vout
		]
		
		
	
	]

]

;--------
;-   SLIM HEADER
[
    title: "config manager" 
    author: none 
    file: none 
    date: 13-May-2008 
    version: 0.2.13 
    slim-name: 'configurator 
    slim-prefix: none 
    slim-version: 0.9 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: CONFIGURATOR
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: UTILS  v1.0.1
;--------------------------------------------------------------------------------

append slim/linked-libs 'utils
append/only slim/linked-libs [


;--------
;-   MODULE CODE




slim/register/header [
	

	;-----------------------------------------------------------------------
	;- SCRIPT ENVIRONMENT CONTROL.
	;-----------------------------------------------------------------------
	
	;-----------------
	;-     get-application-title()
	;-----------------
	get-application-title: func [
		/local script parent
	][
		parent: system/script
		until [
			;print parent/header
			script: parent
			parent: script/parent
			any [
				none? parent
				none? parent/header
			]
		]
		script/title
	]	
	
	;-  
	;-----------------------------------------------------------------------
	;- WORDS
	;-----------------------------------------------------------------------
	;-----------------
	;-     swap-values()
	;
	; given two words, it will swap the values these words reference or contain.
	;-----------------
	swap-values: func [
		'a 'b 
		/local c
	][c: get a set a get b set b  c]
	
		
	
	
	
	
	
	
	;-  
	;-----------------------------------------------------------------------
	;- DATES
	;-----------------------------------------------------------------------
	
	;--------------------
	;-    date-time()
	;--------------------
	; use this to prevent having to supply a spec all the time.
	; the /default option of date-time sets this.
	default-date-time-spec: "YYYY-MM-DD"
	;---
	date-time: func [
		""
		/with spec ; specify
		/using thedate [string! date! time!] ; specify an explicit date instead of now()
		/default ; set the default to /with spec
		/local str date-rules thetime
	][
		;vin ["date-time()"]
		
		str: copy ""
		
		
		either spec [
			if default [
				default-date-time-spec: spec
			]
		][
			spec: default-date-time-spec
		]
		
		unless thedate [
			thedate: now/precise
		]
		
		;probe thedate
		either time? thedate [
			thetime: thedate
			thedate: none
			
			
		][
			if thedate/time [
				thetime: thedate/time
				thedate/time: none
			]
		]
		
		filler: complement charset "YMDHhmspP"
		;error: spec
		itime: true
		
		
		unless parse/case spec [
			some [
				here:
				(error: here)
				; padded dates
				["YYYY" (append str thedate/year)] | 
				["YY" (append str copy/part at to-string thedate/year 3 2)] | 
				["MM" (append str zfill thedate/month 2)] |
				["DD" (append str zfill thedate/day 2)] |
				["M" (append str thedate/month)] |
				["D" (append str thedate/day)] |
				
				; padded time
				["hh" (append str zfill thetime/hour 2)] |
				["mm" (append str zfill thetime/minute 2)] |
				["ss" (append str zfill to-integer thetime/second 2)] |
				
				; am/pm indicator
				["P" (append str "#@#@#@#")] | 
				["p" (append str "-@-@-@-")] | 
				
				; american style 12hour format
				["H" (
					itime: remainder thetime/hour 12
					if 0 = itime [ itime: 12]
					append str itime
					itime: either thetime/hour >= 12 ["PM"]["AM"]
					)
				] |
				
				; non padded time
				["h" (append str thetime/hour)] |
				["m" (append str thetime/minute)] |
				["s" (append str to-integer thetime/second)] |
				["^^" copy val skip (append str val)] |
				
				[copy val some filler (append str val)]
				
			]
			(replace str "#@#@#@#" any [to-string itime ""])
			(replace str "-@-@-@-" lowercase any [to-string itime ""])
		][
			to-error rejoin [
				"date-time() DATE FORMAT ERROR: " spec newline
				"  starting at: "  error newline
				"  valid so far: " str newline
			]
		]
		;vout 
		str
	]
	

	;-  
	;-----------------------------------------------------------------------
	;- PAIRS
	;-----------------------------------------------------------------------
	;-----------------
	;-     ydiff()
	;-----------------
	ydiff: func [
		a [pair!] b [pair!]
	][
		;a/y - b/y
		second a - b ; this is twice as fast as above line
	]
	
	
	;-----------------
	;-     xdiff()
	;-----------------
	xdiff: func [
		a [pair!] b [pair!]
	][
		;a/x - b/x
		first a - b ; this is twice as fast as above line
	]
	

	
	
	
	;-  
	;-----------------------------------------------------------------------
	;- SERIES
	;-----------------------------------------------------------------------
	;-----------------
	;-     remove-duplicates()
	;
	; like unique, but in-place
	; removes items from end
	;-----------------
	remove-duplicates: func [
		series
		/local dup item
	][
		;vin [{remove-duplicates()}]
		
		until [
			item: first series
			if dup: find next series item [
				remove dup
			]
			
			tail? series: next series
		]
		
		;vout
		series
	]
	
	;-----------------
	;-     text-to-lines()
	;-----------------
	text-to-lines: func [
		str [string!]
	][
		either empty? str [
			copy ""
		][
			parse/all str "^/"
		]
	]
	
	;-----------------
	;-     shorter?/longer?/shortest/longest()
	;-----------------
	shorter?: func [a [series!] b [series!]][
		lesser? length? a length? b
	]
	
	longer?: func [a [series!] b [series!]][
		greater? length? a length? b
	]
	
	shortest: func [a [series!] b [series!]] [
		either shorter? a b  [a][b]
	]
	
	longest: func [a [series!] b [series!]] [
		either longer? a b  [a][b]
	]	
		
	;-----------------
	;-     shorten()
	; returns series truncated to length of shortest of both series.
	;-----------------
	shorten: func [
		a [series!] b [series!]
	][
		head either shorter? a b [
			clear at b 1 + length? a
		][
			clear at a 1 + length? b
		]
	]
	
	;-----------------
	;-     elongate()
	; returns series elongated to longest of both series.
	;-----------------
	elongate: func [
		a [series!] b [series!]
	][
		either longer? a b [
			append b copy at a 1 + length? b
		][
			append a copy at b 1 + length? a
		]
	]
		
	;-----------------
	;-     include()
	;
	; will only add an item if its not already in the series
	;-----------------
	include: func [
		series [series!]
		data
	][
		;vin [{include()}]
		unless find series data [
			append series data
		]
		;vout
	]


	;-----------------
	;-     find-same()
	;
	; like find but will only match the exact same series within a block.  mere equivalence is not enough.
	;-----------------
	find-same: func [
		series [block!]
		item [series! none! ]
		/local s 
	][
		unless none? item [
			while [s: find series item] [
				if same? first s item [return  s]
				series: next s
			]
		]
		none
	]




	
	;-  
	;-----------------------------------------------------------------------
	;- BLOCK
	;-----------------------------------------------------------------------
	
	;-----------------
	;-     include-different()
	;-----------------
	include-different: func [
		blk [block!]
		data [series!]
	][
		;vin [{include-different()}]
		unless find-same blk data [
			append blk data
		]
		;vout
	]

	
	
	;-  
	;-----------------------------------------------------------------------
	;- STRING
	;-----------------------------------------------------------------------
	;--------------------
	;-    zfill()
	;--------------------
	zfill: func [
		"left fills the supplied string with zeros to amount size."
		string [string! integer! decimal!]
		length [integer!]
	][
		if integer? string [
			string: to-string string
		]
		
		if (length? string) < length [
			head insert/dup string "0" (length - length? string)
		]
		head string
	]


	;--------------------
	;-    fill()
	;--------------------
	fill: func [
		"Fills a series to a fixed length"
		data "series to fill, any non series is converted to string!"
		len [integer!] "length of resulting string"
		/with val "replace default space char"
		/right "right justify fill"
		/truncate "will truncate input data if its larger than len"
		/local buffer
	][
		unless series? data [
			data: to-string data
		]
		val: any [
			val " " ; default value
		]
		buffer: head insert/dup make type? data none val len
		either right [
			reverse data
			change buffer data
			reverse buffer
		][
			change buffer data
		]
		if truncate [
			clear next at buffer len
		]
		buffer
	]
	
	
	;-  
	;-----------------------------------------------------------------------
	;- FILES
	;-----------------------------------------------------------------------

	
	;-------------------
	;-    as-file()
	;
	; universal path fixup method, allows any combination of file! string! types written as 
	; rebol or os filepaths.
	;
	; also cleans up // path items (doesnt fix /// though).
	;
	; NOTE: this function cannot support url-encoded strings, since there
	;   is a bug in path notation which doesn't properly convert string! to/from path!.
	; 
	;   for example the space (%20), when it is the first character of the string, will stick as "%20" 
	;   (and become impossible to decipher when probing the path)
	;   instead of becoming a space character.
	; 
	;   so we take for granted that the '%' prefix, is a path prefix and simply remove it.
	;-----
	as-file: func  [
		path [string! file!]
	][
		to-rebol-file replace/all any [
			all [
				path/1 = #"%"
				next path
			]
			path
		] "//" "/"
	]
	
	
	
	;-   
	;-----------------------------------------------------------------------
	;- MATH
	;-----------------------------------------------------------------------
	;-----------------
	;-     atan2()
	;-----------------
	atan2: func [
		v [pair!]
	][
		any [
			all [v/y > 0  v/x > 0  arctangent v/y / v/x]
			all [v/y >= 0 v/x < 0 180 + arctangent v/y / v/x]
			all [v/y < 0  v/x < 0 180 + arctangent v/y / v/x]
			all [v/y >  0 v/x = 0 90 ]
			all [v/y <  0 v/x = 0 270]
			all [v/y < 0  v/x >= 0 360 + arctangent v/y / v/x]
			0
		]
	]
	
	;-----------------
	;-     hypothenuse()
	;-----------------
	hypothenuse: func [
		width
		height
	][
		square-root (width * width) + (height * height)
	]
	
	
	
	

	
	
]

;--------
;-   SLIM HEADER
[
    title: {Stripped-down version of moliad utility functions library.} 
    author: "Maxim Oliver-Adlhoch" 
    file: %utils.r 
    date: 31-Jan-2010 
    version: 1.0.1 
    slim-name: 'utils 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: UTILS
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: EPOXY  v0.4.1
;--------------------------------------------------------------------------------

append slim/linked-libs 'epoxy
append/only slim/linked-libs [


;--------
;-   MODULE CODE




;- slim/register/header
slim/register/header [
	; declare words so they stay bound locally to this module
	!plug: liquify*: !glob: content*: fill*: link*: unlink*: process*: none
	
	liquid-lib: slim/open/expose 'liquid none [!plug [liquify* liquify ] [content* content] [fill* fill] [link* link] [process* process]]
	glob-lib: slim/open/expose 'glob none [!glob]
	
	sillica-lib: slim/open 'sillica none
	
	
	;- FUNCTION
	;-----------------
	;-     calculate-expansion()
	;-----------------
	calculate-expansion: func [
		fd  ; frame-dimension
		fms ; frame-min-size
		ftw ; frame-total-weight
		ms  ; min-size
		rw  ; region-weight
		re  ; region-end
		sp  ; total-spacing - removed from frame-dimension & frame-dimension
	][
		vin [{calculate-expansion()}]
		; xtra space in frame, note we don't allow shrinking, 
		; reduce min-size to shrink.
		xs: max 0 fd - fms
		
		

		; quick verification.
		either any [
			rw = 0
			ftw = 0
		][
			vout
			; default size is min-size
			ms
		][
			; remove spacing from calculations.
			fd: fd - sp
			fms: fms - sp
	
			vout
			ms + (to-integer (( re / ftw ) * xs)) - (to-integer ((( re - rw ) / ftw) * xs))
		]
	]
	
		
	;-----------------
	;-     intersect-region()
	;-----------------
	intersect-region: func [
		frame-start
		frame-end
		marble-start
		marble-end
	][
		;vin [{glass/intersect-region()}]
		
		start: max frame-start marble-start
		end: min frame-end marble-end
		
		if any [
			end/x < start/x
			end/y < start/y
		][
			start: -1x-1
			end: -1x-1
		]
		
		;vout
		
		reduce [start end]
	]
	
	
	
	
	
	
	;----------------------------------------------------------
	;-
	;- NEW LOW-LEVEL GENERIC PLUGS
	
	;-----------------
	;-     !inlet:
	;
	; this is set to become an official liquid node, used where speed and efficiency is a concern and 
	; dynamic plug computation change is not required.
	;
	; it cannot be linked, but it may be piped or used as a container.
	;
	; it is especially usefull as the input of high-performance, highly-controled liquid networks.
	;
	; this can be considered an "edge" in academia graph theory.
	;-----------------
	!inlet: make !plug [
	
	]
	
	
	;-----------------
	;-     !junction:
	;
	; this is set to become an official liquid node, used where speed and efficiency is a concern and 
	; dynamic plug computation change is not required.
	;
	; major differentiation:
	;     -extra fast, optimisized for speed
	;     -it cannot be piped, or used as a container (use !inlet for that)
	;     -filtering is limited to a count of items in subordinates
	;     -no purification
	;     -data block of process() is reused at each call (be carefull).
	;     
	;
	; it is especially usefull as the processing element of high-performance, highly-controled liquid networks.
	;
	; this can be considered a "node" in academia graph theory.
	;-----------------
	!junction: make !plug [
	
	]
	

	;-     !pair-op[]
	!pair-op: make !junction [
		valve: make valve [
			type: '!pair-op
			
			
			; set this to any function you need within your class derivative.
			operation: :add
			
			
			;-         direction:
			direction: 1x1
			
			
			;-----------------
			;-         process()
			;-----------------
			process: func [
				plug data
				/local item
			][
				;vin [{epoxy/} uppercase to-string plug/valve/type {[}plug/sid{]/process()}]
				;data
				plug/liquid: direction * any [pick data 1 0]
				;print [ "--------" uppercase to-string plug/valve/type "-------->" ]
				;print plug/liquid
				
				;if plug/valve/type = '!pair-max [probe data]
				foreach item next data [
					plug/liquid: operation plug/liquid item * direction
				]
				;vout
			]
			
			
		]
	]
	
	;-     !pair-add:
	!pair-add: make !pair-op [valve: make valve [type: '!pair-add]]
	
	
	;-     !pair-subtract:
	!pair-subtract: make !pair-op [valve: make valve [type: '!pair-subtract operation: :subtract]]
	
	
	;-     !pair-max:
	!pair-max: make !pair-op [valve: make valve [type: '!pair-max operation: :max]]
	
	
	
	
	
	;-     !fast-add:
	; fast and safe add function.
	!fast-add: make !junction [
		valve: make valve [
			type: '!fast-add
			
			;-----------------
			;-         process()
			;-----------------
			process: func [
				plug
				data
			][
				vin [{epoxy/!fast-add/process()}]
				;probe data
				plug/liquid: if 1 < length? data [
					add first data second data
				][0]
				vout
			]
			
		]
			
	]
	
	;-     !fast-sub:
	; fast and safe subtract function.
	!fast-sub: make !junction [
		valve: make valve [
			type: '!fast-sub
			
			;-----------------
			;-         process()
			;-----------------
			process: func [
				plug
				data
			][
				vin [{epoxy/!fast-add/process()}]
				plug/liquid: if 1 < length? data [
					subtract first data second data
				][0]
				vout
			]
			
		]
			
	]
	
	;-     !range-sub:
	; subtract a range from another.
	;
	; the detail is that the range is inclusive, so must be One more  
	; than the 0-based matb subtract
	!range-sub: make !junction [
		valve: make valve [
			type: '!range-sub
			
			;-----------------
			;-         process()
			;-----------------
			process: func [
				plug
				data
			][
				vin [{epoxy/!fast-add/process()}]
				plug/liquid: if 1 < length? data [
					1 + subtract first data second data
				][0]
				vout
			]
			
		]
			
	]
	
	
	
	;-     !to-pair:
	;
	; using one or two inputs, output a pair
	;
	; one input will output in X & Y,  two outputs will use the 
	; first value in X and second in Y.
	;
	; note that if the input(s) have different items (pair, block, tuple, etc)
	; the X will use xdata/1  and  Y will use ydata/2 
	!to-pair: make !inlet [
		valve: make valve [
		
			;-         type:
			type: 'to-pair
			
	
			;-----------------
			;-         process()
			;-----------------
			process: func [
				plug
				data
				/local xdata ydata
			][
				vin [{to-pair/process()}]
				plug/liquid: either switch length? data [
					1 [
						xdata: first data
						ydata: xdata
					]
					
					2 [
						xdata: first data
						ydata: second data
					]
				][
					if find [ tuple! pair! block! ] type?/word xdata [
						xdata: xdata/1
					]
					xdata: 1x0 * any [xdata 0]
					
					if find [ tuple! pair! block! ] type?/word ydata [
						; in case block isn't of length 2, we fallback to length 1
						ydata: any [ydata/2 ydata/1]
					]
					ydata: 0x1 * any [ydata 0]
					
					xdata + ydata
				][ 	
					0x0
				]
				
				vout
			]
			
		]
	]
	
	
	;-     !integers-to-pair: []
	!integers-to-pair: process* '!integers-to-pair [
		x y
	][
		vin "!integers-to-pair()"
		x: any [pick data 1 0]
		y: any [pick data 2 x]
		plug/liquid: (1x0 * x) + (0x1 * y)
		vout
	]
	
	;-     !negated-integers-to-pair: []
	!negated-integers-to-pair: process* '!negated-integers-to-pair [
		x y
	][
		vin "!integers-to-pair()"
		x: any [pick data 1 0]
		y: any [pick data 2 x]
		plug/liquid: (-1x0 * x) + (0x-1 * y)
		vout
	]
	
	
	;-     !merge[]
	;
	; simply returns a all inputs accumulated into one single block.
	; 
	;
	; inputs:
	;    expects to be used linked... doesn't really make sense otherwise
	;
	;    any data can be linked except for unset!
	;    block inputs are merged into a single block, but their block contents aren't.
	;
	;  so:
	;     [[111] [222] 333 [444 555 [666]]]  
	;
	;  becomes:
	;     [111 222 333 444 555 [666]]
	;
	;
	; note that chaining !merge plugs will preserve these un merged blocks in an indefinite
	; number of sub links, because the liquid is a block.
	; 
	; ex using the above:
	;     [ [111 222 333 444 555 [666]]  [111 222 333 444 555 [666]] ]
	;
	; becomes:
	;     [ 111 222 333 444 555 [666]  111 222 333 444 555 [666] ]

	!merge: make !plug [
		valve: make valve [
			type: 'merge
			
			
			;-----------------
			;-         process()
			;-----------------
			process: func [
				plug
				data
			][
				vin [{process()}]
				; we reuse the same block at each eval (saves series reallocation & GC overhead)
				plug/liquid: clear []
				
				foreach item data [
					append plug/liquid :item
				]
				vout
			]
		]
	]
	
	
	;-----------------
	;-     !x-from-pair:[]
	;-----------------
	!x-from-pair: process* '!x-from-pair [
	][
		vin [{!x-from-pair()}]
		plug/liquid: first first data
		vout
	]
	
	;-----------------
	;-     !y-from-pair:[]
	;-----------------
	!y-from-pair: process* '!y-from-pair [
	][
		vin [{!y-from-pair()}]
		plug/liquid: second first data
		vout
	]
	
	
	
	
	;-     !select[]
	;
	; inputs:
	;     member:  a word to get/select in context.
	;     context: an object or block of word/value pairs
	;
	; using this as a linked container makes a lot of sense.
	;     you set the member as the filled value
	;     and link the context to get value from
	!select: make !plug [
		valve: make valve [
			type: 'select
			
			;-----------------
			;-         process()
			;-----------------
			process: func [
				plug
				data
				/local w o
			][
				;vin [{process()}]
				
				;print "EPOXY/SELECT"
				
				plug/liquid: if all [
					word? w: pick data 1
					any [
						object? o: pick data 2
						block? o
					]
				][
					either object? o [
						; safe if member not part of o
						get in o w
					][
						select o w
					]
				]
				;probe data
				;probe plug/liquid
				;vout
			]
		]
	]
	
	
	;-     !chose-items: [p]
	!chose-items: process* '!chose-items [blk chosen][
		plug/liquid: any [
			if all [
				block? blk: pick data 1
				block? chosen: pick data 2
				not empty? chosen
				not empty? blk
			][
				search-bulk-column/all/row/same blk 'label-column chosen
			] 
			; if inputs are invalid, return empty block.
			copy []
		]
	]
	
	
	
	;----------------------------------------------------------
	;-  
	;- BULK HANDING
	
	
	
	;------------------------------
	;-     !bulk-row-count[]
	;
	; returns the number of rows in an bulk using a flat block as data and 
	; a column size
	;
	; if the column size isn't linked, the we fallback to 1, usefull for lists.
	!bulk-row-count: make !plug [
	
		valve: make valve [
			type: 'row-count
			
			;-----------------
			;-         process()
			;-----------------
			process: func [
				plug 
				data
				/local blk cols
			][
				vin [{!bulk-row-count/process()}]
				
				plug/liquid: either all [
					block? blk: pick data 1
					any [
						integer? cols: bulk-rows blk
						;cols: 1
					]
				][
					cols
				][
					; we normalize the value to an integer, if first input isn't a block or not a bulk.
					1
				]
				
				vout
			]
		]
	]
	

	
	;----------------------------------------
	;-     !bulk-filter: [process*]
	;
	; inputs:
	;     bulk [block!]: MUST BE A VALID BULK
	;     filter-label(s) [string! block!]: if its a block, it must only contain strings! furthermore these must be the same string! reference (not mere equivalent strings)
	;
	; optional inputs:
	;     mode [word!]: switches how the filter operates, its 'simple by default
	;					currently supported: 'simple, 'same
	;
	;                   when 'same is used, only the exact same strings will be left in bulk,
	;                   even if other strings match the text itself.
	; output:
	;     a copy of the input bulk with only items from filter
	; be carefull, if the first input isn't a proper bulk, liquid WILL BE NONE
	; 
	;----------------------------------------
	!bulk-filter: process* '!bulk-filter [filter-mode spec][
		vin "!bulk-filter/process()"
		
		spec: pick data 2
		plug/liquid: if all [
			spec
			is-bulk? first data
		][
			filter-mode: any [pick data 3 'simple]
			switch filter-mode [
				simple [
					; !bulk-filter is used to filter chosen block in list style.
					; in this case link a dummy plug with the value 'same to it.
					plug/liquid: filter-bulk first data filter-mode reduce ['label-column spec]
				]
				same [
					spec: any [
						all [block? spec spec]
						all [string? spec reduce [spec]]
					] 
					plug/liquid: filter-bulk first data filter-mode spec
				
				]
			]
		] 
		vout 
	]
	



	
	;-     !bulk-label-analyser[p]
	;
	; analyse all the labels in a datablock column and return a new datablock with results
	; 
	; inputs:
	;    (required)
	;	 	bulk:   block!    bulk bulk
	;		------columns: integer!  number of columns in bulk
	;		font:    object!   a view font to use for label size analysis
	;		leading: integer!  extra space between lines.
	;
	;    (optional)
	;		offset: pair!         add this offset to positions
	;		clip-width: integer!  when  providing length info. clip it to this pixel width.
	;		------column:  integer!  column index to use as the label field (1 by default).
	;
	; output:
	;	 a new bulk with one row of information foreach label
	;
	; format:
	;	 ["label" label-length text-dimension from-position to-position]
	;
	; notes:
	;    -if clip-width is given, length may be less than actual label length
	;    -for performance reasons, the plug's liquid is reused at each process, do not tamper 
	;     with it outside of plug or application corruption may occur.
	;
	!bulk-label-analyser: make !plug [
		valve: make valve [
			;-----------------
			;-         process()
			;-----------------
			process: func [
				plug data
				/local bulk columns column font leading offset clip-width
				       blk position line-height size label labels total-size
			][
				vin [{!bulk-label-analyser/process()}]
				; we re-use context
;				vprobe data
				
				either plug/liquid [
					; erase previous bulk data, but keep bulk itself.
					clear-bulk plug/liquid
				][
					; create a new bulk with 5 item records
					plug/liquid: make-bulk 5
				]


				; make sure interface conforms
				if all [
					;------
					; required inputs
					3 <= length? data
					block? bulk: pick data 1
					object? font: pick data 2
					integer? leading: pick data 3
				][
					;------
					;	clean up optional inputs
					position: offset: any [
						all [pair? offset: pick data 4  offset ] 
						0x0
					]
					
					; not yet supported, but will be shortly, when list is updated to use
					; bulk dataset
					clip-width: 1x0 * any [
						all [
							clip-width: pick data 5
							any [pair? clip-width number? clip-width]
							clip-width
						]
						0
					]
					
					columns: get-bulk-property bulk 'columns
					
					; if this bulk has a defined label column use it, otherwise use the first one by default.
					column: any [get-bulk-property bulk 'label-column 1]
					line-height: font/size + leading * 0x1


;					?? bulk
;					v?? columns
;					v?? font
;					v?? leading
;					v?? position
;					v?? clip-width
;					v?? column
;					v?? columns
;					v?? line-height

					;skip bulk header
					bulk: next bulk
					labels: extract at bulk column columns


					;v?? bulk
					
					; calculate total width
					total-size: 0x0
					foreach label labels [
						total-size: max total-size sillica-lib/label-dimension label font
					]
					
;					v?? total-size
					
					foreach label labels [
;						vprint label
						
						size: sillica-lib/label-dimension label font
						
						add-bulk-records plug/liquid reduce [
							label 
							length? label 
							size 
							position
							position + line-height + ( 1x0 * total-size)
						]
						
						position: position + line-height
					]
					
				]
				vout
			]
			
			
		]
	]	


	
	;-     !bulk-label-dimension[p]
	;
	; using data from the bulk-label-analyser, return the dimension of the box
	;
	; inputs :
	;     a bulk returned from bulk-label-analyser
	;
	!bulk-label-dimension: make !plug [
		valve: make valve [
			;-----------------
			;-         process()
			;-----------------
			process: func [
				plug
				data
				/local bulk from to
			][
				vin [{!bulk-label-dimension/process()}]
				
				
				plug/liquid: either all [
					is-bulk? bulk: pick data 1
					pair? from: pick (get-bulk-row bulk 1) 4
					pair? to: last bulk
				][
					to - from
				][
					; at least the output won't crash processes depending on a pair.
					; the -1x-1 value in GLASS has a special meaning which equates to "unspecified".
					-1x-1
				]
				
				vout
			]
			
			
		]
	]
	
	
	
	;------------------------------
	;-     !bulk-lines[p]
	;
	;  this is a node which takes any input and purifies it into a one column bulk with one row per line
	;  it is used in the text editors.
	;  
	;  input:
	;    any plug, but is very effective as a pipe server, since the convertion is done in purify() instead of process()
	;
	;  output:
	;    a bulk or lines, 1 line per row.
	;
	;  notes:
	;	will convert any input to bulk text output, none will become a single empty row. [""]
	;
	;   when plugging in bulk into this node (fill or link) be carefull not to provide invalid data.
	;
	;   if the input is already a bulk, it will output the first column of that bulk.
	;   if the input buld already is a single column, it will output it AS-IS not doing any convertion.
	;
	;   it is valid to edit the content in place and simply call notify on the bulk since this allows
	;   great memory saving.
	;
	;   note that we use only the first value which is linked into the plug.
	!bulk-lines: make !plug [
	
		valve: make valve [
			type: 'bulk-lines
			
			
			;-----------------
			;-         process()
			;-----------------
			process: func [
				plug
				data
			][
				plug/liquid: pick data 1
			]
			
			;-----------------
			;-         purify()
			;
			; because we do the convertion in purify rather that process,
			; any changes done here will persist and no memory copy will take place
			; unless required.
			;
			; this also allows the plug to be used as a pipe server output filter as-is
			;-----------------
			purify: func [
				plug
				/local blk str
			][
				vin [{purify()}]
				
				switch/default type?/word plug/liquid [
					block! [
						; do nothing, we expect data to be a bulk
					]
					string! [
						str: plug/liquid
						; we convert the text to a bulk
						blk: make-bulk 1
						append blk sillica-lib/text-to-lines str
						plug/liquid: blk
					]
				][
					; useful universal convertion
					str: mold plug/liquid
					blk: make-bulk 1
								
					append blk probe parse/all str "^/"

					plug/liquid: blk
				]
				;print "."
				vout
				false
			]
		]
	]

	;------------------------------
	;-     !bulk-join-lines[p]
	;
	; counter part to bulk-lines which takes the bulk and purifies it into a single string of text.
	;------------------------------
	!bulk-join-lines: make !plug [
	
		valve: make valve [
			type: 'bulk-join-lines
			
			;-----------------
			;-         process()
			;-----------------
			process: func [
				plug
				data
			][
				plug/liquid: pick data 1
			]
			
			;-----------------
			;-         purify()
			;
			; because we do the convertion in purify rather that process,
			; any changes done here will persist and no memory copy will take place
			; unless required.
			;
			; this also allows the plug to be used as a pipe server output filter as-is
			;-----------------
			purify: func [
				plug
				/local blk str
			][
				vin [{purify()}]
				
				switch/default type?/word plug/liquid [
					block! [
						str: copy ""
						foreach line next plug/liquid [
							append str join line "^/"
						]
						plug/liquid: str
					]
					string! [
						; do nothing, we expect data to be a string
					]
				][
					; useful universal convertion
					str: mold plug/liquid
					plug/liquid: str
				]
				;print "."
				vout
				false
			]
		]
	]
	
	
	;----------------------------------------------
	;-    !bulk-sort[process*]
	;----------------------------------------------
	; takes a bulk and sorts each column according to a default of given column
	;
	;  inputs:
	;    -bulk to sort [bulk!]
	;    -column to sort on (optional)[integer! word!], if not given, we use the bulk's default label column, or first column.
	;
	;  output:
	;    a new bulk which is sorted.
	;
	;  notes:
	;     we SHARE any series or compound data from input bulk, all we do is re-organise it within a new block!
	;----------------------------------------------
	!bulk-sort: process* '!bulk-sort [blk sort-column columns][
		either is-bulk? blk: pick data 1 [
			columns: bulk-columns blk
			; given sort column
			sort-column: pick data 2 
			
			plug/liquid: any [
				all [
					; reuse previous liquid block!
					block? plug/liquid 
					clear plug/liquid
					append plug/liquid blk
				] 
				
				; create new liquid
				copy blk
			]
			bulk-sort/using plug/liquid sort-column
			
		][
			; the input was not a bulk, just output some empty default bulk
			; here we re-use to prevent memory recycling abuse.
			either is-blk? plug/liquid [
				clear-bulk plug/liquid
			][
				plug/liquid: make-bulk 1
			]
		]
	]
	
	

	
	;----------------------------------------------------------
	;-  
	;- GRAPHICS PLUGS

	;------------------------------
	;-     !image-size[]
	;
	;  expects an image input, 
	;
	;  output:
	;    a pair which is the size of the input image
	;
	;  notes:
	;     will revert to a fallback of 0x0 if the input is not an image:
	;
	; when the intersection is empty, a box of [-1x-1 -1x-1] is returned.  in any other case, all rectangle values are positive.
	!image-size: make !junction [
	
		mode: 'xy ; can also be 'x or 'y
		
		valve: make valve [
			type: 'image-size
			
			;-----------------
			;-         process()
			;-----------------
			process: func [
				plug data
				/local img
			][
				plug/liquid: either image? img: pick data 1 [
					switch plug/mode [
						xy [img/size]
						x [img/size * 1x0]
						y [img/size * 0x1]
					]
				][
					0x0
				]
			]
		]
	]


	
	;------------------------------
	;-     !box-intersection[]
	;
	;  expects two, three OR four inputs, the type of the third input determines mode:
	;     setup A)
	;         pos-a   ( pair! )
	;         size-a  ( pair! )
	;         pos-b   ( pair! )
	;         size-b  ( pair! )
	;
	;     setup B)
	;         pos-a           ( pair! )
	;         size-a          ( pair! )
	;         clip-rectangle  ( [ start: pair! end: pair! ] ) -> from parent-frame
	;
	;     setup C)
	;         pos-a           ( pair! )
	;         size-a          ( pair! )
	;
	;  output:
	;     a clip-rectangle block of two pairs which defines a box
	;    [ start end ] = [pair! pair!] = [20x20 100x100] 
	;
	;  notes:
	;     all coordinates are absolute, sizes should be added to positions.
	;
	; when the intersection is empty, a box of [-1x-1 -1x-1] is returned.  in any other case, all rectangle values are positive.
	!box-intersection: make !junction [
		valve: make valve [
			type: 'box-intersection
			
			;-----------------
			;-         process()
			;-----------------
			process: func [
				plug data
			][
				vin [{epoxy/!box-intersection[} plug/sid {]/process()}]
				; default value is an empty clipping rectangle... meaning don't draw anything !!!
				plug/liquid: [-1x-1 -1x-1]
				
				;v?? data
				
				switch length? data [
					;---
					; setup A
					4 [
						plug/liquid: intersect-region data/1 (data/1 + data/2) data/3  (data/3 + data/4)
					]
					
					;---
					; setup B
					3 [
						; make sure we really have all data... (its not an incomplete 4 input setup)
						if block? pick data 3 [
							plug/liquid: intersect-region data/1 (data/1 + data/2)  data/3/1 data/3/2
						]
					]
					
					;---
					; setup C
					2 [
						; note this could be an incomplete setup A or B
						plug/liquid: reduce [data/1 data/1 + data/2]
					]
					
				]
				
				vprint ["liquid: " mold plug/liquid]
				vout
			]
			
			
		]
	]
	
	
	
	;-     !pin[]
	;
	; calculate relative positioning using several coordinates and reference points.
	;
	; reference point labels are:
	;    center,  
	;    top, T, bottom, B, right, R, left, L
	;    north, N, south, S, east, E, west, W
	;    top-left, TL, top-right, TR, bottom-left, BL, bottom-right, BR
	;    north-west, NW, north-east, NE, south-west, SW, south-east, SE
	;
	; inputs:
	;     coordinates: [from-point to-point]
	;     from-dimension:
	;     to-position:
	;     to-dimension:
	;
	; optional inputs
	;     from-offset: note, this isn't material/position, (position is what we return)
	;
	; note first input is often used as a filled value, used in linked containers.
	
	!pin: process* 'pin [from-point from-offset from-dimension to-point to-offset to-dimension src-off dest-offset] [
	
		plug/liquid: either all [
			block? pick data 1
			word? from-point: pick data/1 1
			word? to-point: pick data/1 2
			
			pair? from-dimension: pick data 2
			pair? to-position: pick data 3
			pair? to-dimension: pick data 4
			pair? from-offset: any [pick data 5 0x0]
		][
			300x300
			;probe length? data
;			?? from-point
;			?? to-point
;			?? from-dimension
;			?? to-position
;			?? to-dimension
;			?? from-offset
		
			src-offset: from-offset + switch/default from-point [
				center [
					to-dimension / 2
				]
			][0x0]
			
			dest-offset: switch/default to-point [
				center [
					from-dimension / -2
				]
			][to-position]
			
			src-offset + dest-offset
		][
			vprint "!pin/process() error:"
			vprobe data
			0x0
		]
	]
	
	
	
	
	
	;-----------------
	;-     !label-min-size()
	;
	; this is a commonly-used and very practical plug
	;
	; inputs:
	;    manual-sizing: [pair! none]
	;    label: [string!]
	;
	; optional inputs:
	;    font: [object!] " if not set, use theme-default-font"
	;    padding: [pair!] "adds respective value to either side of orientation"
	;             default-padding is 3x2
	;    
	; output:
	;    a pair which fits both manual-sizing and automatic-sizing.
	;
	; notes:
	;    if ONLY x or y of manual-sizing are = -1 then that orientation
	;    is auto-calculated, based on the other manual sizing orientation
	;
	;    if both are -1 then its the same as specifying none, in which case
	;    the default box is an unlimited text box in both directions, constrained
	;    only by text sizing including manual line-feeds and font properties.
	;
	;    if text is none, we return (max 0x0 manual-sizing)
	;-----------------
	!label-min-size: process* '!label-min-size [
		man-size label font padding
	][
		vin [{!label-min-size/process()}]
		;probe data
		man-size: pick data 1
		either man-size [
			unless string? label: pick data 2 [
				switch type?/word label [
					;none [""]
				]
			]
			font: any [pick data 3 theme-base-font]
			padding: any [pick data 4 3x2]
			
			
			; determine what to resize
			
			plug/liquid: case [
			
				none? label [
				 (max 0x0 any [man-size 0x0])
				]
			
				; totally fixed minimum size
				all [ pair? man-size  man-size/x <> -1  man-size/y <> -1  ][
					man-size
				]
				
				; total auto-sizing
				man-size = -1x-1 [
					sillica-lib/label-dimension label font
				]
				
				man-size/x = -1 [
					;plug/liquid: 1x1 * man-size/y
					sillica-lib/label-dimension/height label font man-size/y
				]
				
				man-size/y = -1 [
					sillica-lib/label-dimension/width label font man-size/x
				]
				true [0x0]
			]
			
			
			;print ["label size " mold label " : " plug/liquid]
			
			
			; add given or default padding
			if plug/liquid <> 0x0 [
				plug/liquid: plug/liquid + padding + padding
			]
			
		][	
			;probe "AUTO SIZE IS MANUALLY SET TO NONE"
			;ask "!!!"
			; when size is none, no sizing occurs, we just use default glass box-size
			; the generic GLASS box size.
			plug/liquid: 30x30
		]
		
		
		vout
	]
	
	
	
	
	
	
	;-     !vertical-accumulate[]
	;
	; optimised plug which adds up pairs in a single direction.
	; accepts integer or pair values
	!vertical-accumulate: make !junction [
		valve: make valve [
			;-----------------
			;-         process()
			;-----------------
			process: func [
				plug data
				/local item dir
			][
				vin [{epoxy/!vertical-accumulate/process()}]
				; the first data segment is the basis, which is increased by any following plugs
				plug/liquid: 1x1 * any [pick data 1 0x0]
				
				; increase size in X
				; add up size in Y
				foreach item next data [
					plug/liquid: max item item * 0x1 + plug/liquid 
				]
				vout
			]
		]
	]
	
	;-     !horizontal-accumulate[]
	;
	; optimised plug which adds up pairs in a single direction.
	; accepts integer or pair values
	!horizontal-accumulate: make !junction [
		valve: make valve [
			;-----------------
			;-         process()
			;-----------------
			process: func [
				plug data
				/local item dir
			][
				vin [{epoxy/!horizontal-accumulate/process()}]
				; the first data segment is the basis, which is increased by any following plugs
				plug/liquid: 1x1 * any [pick data 1 0x0]
				
				; increase size in X
				; add up size in Y
				foreach item next data [
					;plug/liquid: max plug/liquid item * 1x0 + plug/liquid 
					plug/liquid: max item item * 1x0 + plug/liquid 
				]
				vout
			]
		]
	]
	
	
	
	;-     !vertical-shift[]
	;
	; optimised plug which increases only the Y attribute of first input according to all other connected 
	; inputs
	;
	; accepts any number of integers or pairs linked.
	;
	; cannot be piped.
	!vertical-shift: make !junction [
		valve: make valve [
			;-----------------
			;-         process()
			;-----------------
			process: func [
				plug data
				/local item dir
			][
				vin [{epoxy/!vertical-shift/process()}]
				
				vprobe data
				; the first data segment is the basis, which is increased by any following plugs
				plug/liquid: 1x1 * any [pick data 1 0x0]
				
				; increase size in X
				; add up size in Y
				foreach item next data [
					plug/liquid: max plug/liquid item * 0x1 + plug/liquid 
				]
				vprobe plug/liquid
				vout
			]
		]
	]
	
	;-     !horizontal-shift[]
	;
	; optimised plug which increases only the Y attribute of first input according to all other connected 
	; inputs
	;
	; accepts any number of integers or pairs linked.
	;
	; cannot be piped.
	!horizontal-shift: make !junction [
		valve: make valve [
			;-----------------
			;-         process()
			;-----------------
			process: func [
				plug data
				/local item dir
			][
				vin [{epoxy/!horizontal-shift/process()}]
				
				vprobe data
				; the first data segment is the basis, which is increased by any following plugs
				plug/liquid: 1x1 * any [pick data 1 0x0]
				
				; increase size in X
				; add up size in Y
				foreach item next data [
					plug/liquid: max plug/liquid item * 1x0 + plug/liquid 
				]
				vprobe plug/liquid
				vout
			]
		]
	]
	
	
	;-     !vertical-fill-dimension[]
	; inputs:
	;
	;   frame dimension
	;   frame min-size
	;   marble min-size
	;   marble fill-weight
	;   marble fill-accumulation
				
	!vertical-fill-dimension: make !junction [
		valve: make valve [
			;-----------------
			;-         process()
			;-----------------
			process: func [
				plug
				data
				/local fd fms mms mfw mfa s
			][
				vin [{epoxy/!fill-dimension/process()}]
				

		
				plug/liquid: (1x0 * data/1/x ) + (0x1 * calculate-expansion data/1/y data/2/y data/3/y data/4/y data/5/y data/6/y data/7/y)
						
;				weight    2  1  3  0  2
;				regions  0  2 3   6  6  8
;				graph    |--|-|---|..|--|
;				(index    1  2  3     4 )
;				
;				example: 
;				--------				 
;				available 100
;				min-size   80
;				(extra     20)
;				
;				1.  (0 / 8) * 20 == 0
;				    (2 / 8) * 20 == 5 
;				    ------------------
;				    5 - 0 = min + 5  (5 / 20 total)
;				    
;				2.  (2 / 8) * 20 == 5
;				    (3 / 8) * 20 == 7.5 >> 8
;				    ------------------
;				    8 - 5 = min + 3  (8 / 20 total)
;				    
;				    
;				3.  (3 / 8) * 20 == 7.5 >> 8
;				    (6 / 8) * 20 == 15
;				    ------------------
;				    15 - 8 = min + 7 (15 / 20 total)
;				    
;				4.  (6 / 8) * 20 == 15
;				    (8 / 8) * 20 == 20
;				    ------------------
;				    20 - 15 = min + 5 (20 / 20 total)
				
				; is this marble statically sized?

					
					
				
				
				vout
			]
		]
	]


	;-     !horizontal-fill-dimension[]
	;
	!horizontal-fill-dimension: make !junction [
		valve: make valve [
			;-----------------
			;-         process()
			;-----------------
			process: func [
				plug
				data
				/local fd fms mms mfw mfa s
			][
				vin [{epoxy/!fill-dimension/process()}]
				
				vprobe data

		
				plug/liquid: (1x0 * calculate-expansion data/1/x data/2/x data/3/x data/4/x data/5/x data/6/x  data/7/x) + (0x1 * data/1/y)
						
		
				
				
				vout
			]
		]
	]
	
	
	
	;-         range-clip:
	; a plug which expects to be piped and uses linked inputs as the range and type
	; of value to share.
	range-clip: make !plug [
		linked-container?: true
		
		;-----------------
		;-         process()
		;-----------------
		process: func [
			plug
			data
		][
			vin [{process()}]
			plug/liquid: 1
			if all [
				number? value: pick data 1
				number? min: pick data 2
				number? max: pick data 3
			][
				
			]
			
			
			vout
		]
	]
	
	
	
	;-     !range-scale:
	; 
	;  allows to apply the rule of threes to an amount based on a scale and a min/max range.
	;
	; inputs (unlabeled):
	;     minimum-value:  (integer! decimal! ) 
	;     maximum-value:  same 
	;     amount:         a value within range of min/max (clipped to range as a precaution)
	;     scale:          scale of amount vs min/max range. (number! or pair!)
	;
	; details:
	;     the range is inclusive and is simply max - min
	;
	!range-scale: make !plug [
	
		;-     normalize-counter-scale?:
		;
		; when the scale scale is a pair, it will make sure the result is at least
		; the same amount as the smallest of the two values.
		;
		; this is used for scrollbars, for example to make sure that the knob is 
		; at least square.
		normalize-counter-scale?: true
		
	
		valve: make valve [
			type: 'range-scale
	
			;-----------------
			;-         process()
			;-----------------
			process: func [
				plug
				data
				/local min-val max-val scale amount range
			][
				vin [{range-scale/process()}]
				plug/liquid: either all [
					number? min-val: pick data 1
					number? max-val: pick data 2
					number? amount: pick data 3
					any [
						number? scale: pick data 4
						pair? scale
					]
					
				][
				
					;?? amount
					range: (max-val - min-val) + 1
					amount: min max 0 amount range
					
					;?? min-val
					;?? max-val
					;?? amount
					;?? range
					;?? scale
					
				
					; all is set
					either (0.0) <> (1.0 * amount) [
						(amount / range * scale)
					][
						; adapts to various scale datatypes
						0 * scale
					]
				][
					either scale [
						0 * scale
					][
						; this default may be dangerous as the amount might be expecting another output type.
						0
					]
				]
				
				if plug/normalize-counter-scale? [
					if pair? scale [
						min-val: min scale/x scale/y
						plug/liquid: max plug/liquid 1x1 * min-val
					]
				
				]
				
				vout
			]
		]
	]
	
	
	
	;-     !offset-value-bridge:
	;
	; <TO DO> directly support min/max of type:  pair! tuple!
	;
	; this plug is designed to provide a relationship between spacial coordinates and
	; a single value range.  
	;
	; it is setup as bridge because spacial and value and range are usually unequal but equivalent.
	;
	; channels: 
	;     'offset: the spatial value, bound to 0x0 -> (dimension)
	;     'value:  the data value, rounded and bound to min/max inputs
	;     'ratio:  a 0-1 scaled version of value/min/max. easier to use in code. When bar is full, value is 0.
	;     
	; inputs (unlabeled):
	;     minimum-value:  scalar,  acceptible types (integer! decimal! ) 
	;     maximum-value:  same as minimum-value
	;     range:          spatial range of offset (pair!)
	;     orientation:    tells the bridge, what value in spatial pair to apply (X or Y)
	;
	; details:
	;     minimum-value is inclusive and will be used when offset = 0
	;     maximum-value is inclusivee and will be used when offset = range
	;     when range = 0, minimum-value is used.
	;
	;     when used with a scroller knob, the supplied size should remove knob dimension from marble dimension.
	;     your are thus left with the scrollable part of the scroller range.
	;
	;     the knob dimension should also be linked to min/max/value/dimension, so that is scales automatically.
	; 
	!offset-value-bridge: make !plug [
		
		valve: make valve [
		
			type: 'epoxy-value-bridge-client
		
			pipe-server-class: make !plug [
			
				;-         current-value:
				current-value: 40
				
			
			
				; the pipe-server expects to be linked to other values.
				resolve-links?: true

				valve: make valve [
			
					type: 'OFFSET-VALUE-BRIDGE
				
					pipe?: 'bridge
					
					;-----------------
					;-         process()
					;-----------------
					process: func [
						plug
						data
						/channel ch
						/local val off space min-val max-val tmp-val orientation vertical? ratio loff
					][
;						print "^/"
						vin [{scroller/process()}]
;						?? ch
;						?? data
						val: 0
						off: 0x0
						
;						print ["current " plug/current-value]
						
						space: pick data 4
						min-val: pick data 2
						max-val: pick data 3
						orientation: pick data 5
						
;						?? min-val
;						?? max-val
;						?? orientation
;						?? space
						
						; fix min-max if they are inverted
;						if max-val < min-val [
;							tmp-val: max-val
;							max-val: min-val
;							min-val: tmp-val
;						]
						
						val-range: max-val - min-val
						
;						?? val-range
						
						 
						vertical?: 'vertical = any [orientation orientation: 'vertical]
						
;						?? orientation
						
						space: any [
							all [vertical? space/y]
							space/x
						]
						
						;print "----"
						;?? ch
						
						; if ch is set, it means the mud was set directly.
						; otherwise it means links changed.
						switch/default ch [
							; position
							offset [
								;print "setting value from offset"
								; make sure value is within bounds of scroller
								off: first first data
								
								val: any [
									all [space = 0 min-val]
									all [
										vertical?
										any [
											all [ integer? val-range round/floor (val-range * off/y / space + min-val)]
											all [ (val-range * off/y / space + min-val)]
										]
									]
									any [
										all [ integer? val-range round/floor (val-range * off/x / space + min-val)]
										all [ (val-range * off/x / space + min-val)]
									]
								]
							]
							value [
								;print "setting offset from value"
								val: first first data
								if string? val [
									either integer? val-range [
										val: any [attempt [to-integer val] 0]
									][
										val: any [attempt [to-decimal val] 0]
									]
								]
								;?? space
								;?? val
								off: 1x1 * any [
									;all [space = 0 0x0] ; bar is full enforce to top.
									all [ val-range = 0 0x0]
									all [1x1 * space *  ((val - min-val) / val-range)]
								]
							]
						][
							;print "value-offset-bridge has no mud to use"
							
							;print "I should scale offset to new dimension or values"
							val: any [plug/current-value 0]
							off: 1x1 * any [
								all [ val-range =  0 0x0]
								all [1x1 * space *  ((val - min-val) / val-range)]
							]
						]
						
						space: either vertical? [space * 0x1][space * 1x0]
						
						; make sure offset doesn't go out of bounds (works in both directions)
						off: max min space off 0x0
						loff: either vertical? [off/y][off/x]
						
						; make sure the value doesn't go out of bounds
						val: max min val max-val min-val
						
						; calculate ratio
						
						ratio: any [
							all [val-range = 0 0]
							(val - min-val  ) / val-range
						]
						
;						print "scroller"
;						?? min-val
;						?? max-val
;						?? val
						
						; remember the value so we can use it for unchanneled processes.
						plug/current-value: val
						
						plug/liquid: compose/deep [ 
							value [(val)] 
							offset [(off)] 
							ratio [(ratio)] 
							linear-offset [(loff)]
						]
						plug/mud: none
						;print "------>"
						;print ["value-range bridge: " mold plug/liquid]
						;print "------>"
						vout
					]
				]
			]
		]
	]	
	
	
	
	
	
	
	
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %epoxy.r 
    date: 20-Jan-2011 
    version: 0.4.1 
    slim-name: 'epoxy 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: EPOXY
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: LIQUID  v1.0.5
;--------------------------------------------------------------------------------

append slim/linked-libs 'liquid
append/only slim/linked-libs [


;--------
;-   MODULE CODE





;----
; use following line to determine real code size without comments.
;----
; save %stripped-liquid.r load %liquid.r



slim/register/header [

	verbose: false

	; next sid to assign to any liquid plug.
	; and also tells you how many plugs have been registered so far.
	;-    liquid-sid-count:
	liquid-sid-count: 0


	;----
	;-    plug-list:
	plug-list: make hash! none
	
	
	;-    total-links:
	total-links: 0


	;-    liquid-error-on-cycle?:
	liquid-error-on-cycle?: true
	
	
	;-    do-cycle-check?:
	;
	;do-cycle-check?: false
	
	
	;-    check-cycle-on-link?:
	; this is used to control the cycle? check which is VERY slow on large networks.
	;
	; this should usually be set to true when debugging and developping, but once your code is robust and you can 
	; guarantee cycle? coherence, then it should be set to false, it will vastly improve linking speed.
	;
	; as such, cycle checks are the most demanding operations you can perform on a network of plugs.
	;
	; when set to false, you can still call cycle? manually on any plug.  which is a good thing for user-controled
	; linking verification.  but for the vast majority of links, where a program is handling the connections,
	; the cycle check isn't really needed.
	check-cycle-on-link?: false
	

	;-----------------------------------------
	;-    alloc-sid()
	;-----------------------------------------
	; currently the sid is a simple number, but
	; could become something a bit stronger in time,
	; so this allows us to eventually change the system without
	; need to change any plug generating code.
	;-----------------------------------------
	alloc-sid: func [][
		liquid-sid-count: liquid-sid-count + 1
	]


	;--------------------
	;-    retrieve-plug()
	;--------------------
	retrieve-plug: select-plug: func [
		"return the plug related to an sid stored in the global plug-list"
		sid
	][
		select plug-list sid
	]


	;--------------------
	;-    reindex-plug()
	; If a plug's object was modified, after allocation, the index still points to the old object.
	;
	; this allows us to do the following AFTER a call to liquify:
	;   plug: make plug [...]
	;
	; why?  some toolkits will allocate nodes pre-emptively and then allow an api to
	;       modify the allocated node directly, usually to add new values to the plug itself.
	;
	; if the plug isn't re-indexed, any call to retrieve-plug will still return the old
	; object, and the changes will seem to have vanished!
	;
	; note: It is an ERROR to call reindex-plug on a plug/sid which doesn't exist,
	;       either cause it was not yet intialized or was destroyed.
	;--------------------
	reindex-plug: select-plug: func [
		"replaces the object stored in the plug-list with this new one."
		new-plug
		/local old-plug list
	][
		either old-plug: select plug-list new-plug/sid [
			change find plug-list old-plug new-plug
		][
			to-error "LIQUID/Reindex() called on an unallocated node."
		]
	]


	;-----------------
	;-    freeze()
	;-----------------
	freeze: func [
		plug
	][
		vin [{freeze()}]
		
		plug/frozen?: true
		vout
	]
	
	
	;-----------------
	;-    thaw()
	;-----------------
	thaw: func [
		plug
	][
		vin [{thaw()}]
		
		plug/frozen?: false
		plug/valve/notify plug
		vout
	]
	
	
	
	

	;-
	;-----------------------
	;- FUNCTIONS!
	;-----------------------
	;-----------------------
	;-    liquify()
	;-----------------------
	; v0.6.6 change!!! shared-states are now EXPLICITELY shared from type to instance.
	;                  if you want a set of plugs to share their own shared-states, 
	;                  change it in the reference type object!
	;-----------------------
	liquify: func [
		type [object!] "Plug class object."
		/with spec "Attributes you wish to add to the new plug ctx."
		/as valve-type "shorthand to derive valve as an indepent from supplied type, this sets type/valve/type"
		/fill data "shortcut, will immediately fill the liquid right after its initialisation"
		/piped "since fill now makes containers by default, this will tell the engine to make it a pipe beforehand."
		/pipe "same as piped"
		/link plugs [block! object!]
		/label lbl [word!] "specify label to link to (no use unless /link is also provided)"
		/local plug
	][
		spec: either none? spec [[]][spec]
		
		; unify plugs datatype
;		plugs: compose [(plugs)]

		if object? plugs [
			plugs: compose [(plugs)]
		]
		
		if as [
			spec: append copy spec compose/deep [valve: make valve [type: (to-lit-word valve-type)]]
		]
		plug: make type spec
		;plug/shared-states: type/shared-states
		
		plug/valve/init plug
		
		if any [piped pipe][
			plug/valve/new-pipe plug
		]
		
		if fill [
			plug/valve/fill plug data
		]
		if link [
			;print "#################################"
			link*/label plug plugs lbl
;			forall plugs [
;				either lbl [
;					plug/valve/link/label plug first plugs lbl
;				][
;					plug/valve/link plug first plugs
;				]
;			]
		]
		first reduce [plug plug: plugs: data: none] ; clean GC return
	]



	;-----------------
	;-    destroy()
	;-----------------
	destroy: func [
		plug
	][
		plug/valve/destroy plug
	]
	
	


	;-----------------------------------------
	;-    true?()
	;-----------------------------------------
	true?: func [value][value = true]


	;------------------------------
	;-    count()
	;---
	while*: get in system/words 'while
	count: func [;
		series [series!]
		value
		/while wend
		/until uend
		/within min "we must find at least one value before hitting this index, or else we return 0"
		/local counter i item
	][
		counter: 0
		i: 0
		while* [ 
			(not tail? series)
		][
			i: i + 1
			if find item: copy/part series 1 value [
				counter: counter + 1
			]
			; check if we hit the end condition once we started counting value
			if all [while counter > 0] [
				if not find item wend [
					series: tail series
				]
			]
			; check if we hit the end condition once we started counting value
			if all [until counter > 0] [
				if find item uend [
					series: tail series
				]
			]
			
			; are we past minimum search success range?
			if all [
				within
				counter = 0
				i >= min
			][
				series: tail series
			]
				
			
			series: next series
		]
		
		counter
	];

	
	;-----------------------------------------
	;-    fill()
	;-----------------------------------------
	fill: func [
		"shortcut for a plug's fill method"
		plug [object!]
		value
		/channel ch
	][
		either channel [
			plug/valve/fill/channel plug value ch
		][
			plug/valve/fill plug value
		]
	]
	
	
	;-----------------------------------------
	;-    pipe()
	;-----------------------------------------
	pipe: func [
		"converts a plug into a pipe"
		plug [object!]
		/with val
	][
		unless with [
			val: plug/valve/content plug
		]
		plug/valve/new-pipe plug val
		plug: val: none
	]
	
	
	
	;-----------------------------------------
	;-    content()
	;-----------------------------------------
	content: func [
		"shortcut for a plug's content method"
		plug [object!]
		/channel ch [word!]
	][
		either channel [
			plug/valve/cleanup/channel plug ch
		][
			plug/valve/cleanup plug
		]
	]
	
	cleanup: :content
	
	
	;-----------------
	;-    dirty()
	;-----------------
	dirty: func [
		plug
	][
		plug/valve/dirty plug
	]
	
	
	;-----------------
	;-    notify()
	;-----------------
	dirty: func [
		plug
	][
		plug/valve/notify plug
	]
	
	

	;-----------------------------------------
	;-    link()
	;-----------------------------------------
	link: func [
		"shortcut for a plug's link method"
		observer [object!]
		subordinate [object! block!]
		/label lbl [word! none!]
		/reset "will call reset on the link method (clears pipe or container constraints, if observer is piped)"
		/exclusive "Only allow one link per label or whole unlabled plug"
		/local blk val
	][
		;probe first subordinate
		;probe mold/all head subordinate
		
		either block? subordinate [
			;probe subordinate
			;vprobe reduce ["linking a block of plugs: " extract subordinate 2]
			;probe length? subordinate
			forall subordinate [
				val: pick subordinate 1
				
				either any [
					set-word? :val
					lit-word? :val
				][
					change subordinate to-word val
				][
					;print ["APPLYING :  type?: " type? val]
					 
					change subordinate do val
					;probe type? pick subordinate -1
				]
			]
			blk: subordinate: head subordinate
		][
			blk: subordinate: compose [(subordinate)]
		]
		foreach subordinate blk [
			; we can now specify the label directly within the block, so we can spec a whole labeled 
			; link setup in one call to link
			either word? subordinate [
				lbl: subordinate
			][
				
				any [
					all [lbl reset       observer/valve/link/label/reset observer subordinate lbl]
					all [lbl exclusive   observer/valve/link/label/exclusive observer subordinate lbl]
					all [lbl             observer/valve/link/label observer subordinate lbl]
					all [reset    (reset: none true)       observer/valve/link/reset observer subordinate ]
					all [exclusive       observer/valve/link/exclusive observer subordinate ]
					observer/valve/link observer subordinate
				]
			]
		]
	]
	
	;-----------------
	;-    unlink()
	;-----------------
	unlink: func [
		observer
		/detach
		/only subordinate [object!] "unlink only specified subordinate from observer, silently ingnores invalid subordinate"
	][
	
		if detach [
			observer/valve/detach observer
		]
	
		either only [
			observer/valve/unlink/only observer subordinate
		][
			observer/valve/unlink observer
		]
	]
	
	
	
	
	;-----------------
	;-    attach()
	;-----------------
	attach: func [
		observer
		pipe
		/to channel
		/preserve "our value is kept when attaching, so that the pipe will immediately use our value(we fill pipe)"
		/local val
	][
		if preserve [
			val: content observer
		]
		either to [
			observer/valve/attach/to observer pipe channel
		][
			observer/valve/attach observer pipe
		]
		if preserve [
			fill observer val
		]
	]
	
	;-----------------
	;-    detach()
	;-----------------
	detach: func [
		plug
		/only
	][
		either only [
			plug/valve/detach/only plug
		][
			plug/valve/detach plug
		]
		
	]
	
	
	
	; just memorise so we can use this enhanced version within liquify
	link*: :link


	;--------------------
	;-    objectify()
	;--------------------
	objectify: func [
		"takes a process func data input and groups them into an object."
		;plug [object!]
		data [block!]
		/local blk here plugs
	][
		blk: compose/only [unlabeled: (plugs: copy [])]
		parse data [
			any [
				[here: word! (append blk to-set-word pick here 1 append/only blk plugs: copy [])]
				|
				[here: skip (append plugs pick here 1)]
			]
		]
		
		
		
		; parse plug/subordinates
		context blk
		
	]


	;--------------------
	;-    is?()
	;--------------------
	is?: func [
		"tries to find a word within the valve definition which matches qualifier: '*qualifier*"
		plug [object!]
		qualifier [word!]
	][
		;print "IS?"
		found? in plug/valve to-word rejoin ["*" qualifier "*"]
	]
			
	;-----------------
	;-    plug?()
	;-----------------
	plug?: func [
		plug "returns true if object is based on a liquid plug"
	][
		all [
			object? plug
			in plug 'liquid
			in plug 'valve
			in plug 'dirty?
			object? plug/valve
			in plug/valve 'setup
			in plug/valve 'link
			in plug/valve 'cleanup
			true
		]
	]
	
	


	;- PLUG CLASS MACROS
	;
	; the following are considered macros, which allow simple wrapping around common plug class creation.
	; the returned plugs are NOT liquified.
	
	;-----------------
	;-    process()
	;
	; creates a simple plug which expets to be linked, building the process() function
	; automatically and returning the new plug class.
	;-----------------
	process: func [
		type-name [word!]
		locals [block!] "plug and data will be added to your process func"
		body [block!]
		/with user-spec [block!] "give a spec block manually"
		/like refplug [object!] 
		/local plug spec
	][
		vin [{process()}]
		spec: [
			valve: make valve [
				type: type-name
				
				process: make function! head insert locals [plug data /local] body
			]
		]
		
		if user-spec [
			insert spec user-spec
		]
		
		plug: make any [refplug !plug] spec
		vout
		plug
	]
	
	
	;-----------------
	;-    bridge()
	;
	; creates two plugs.
	;
	; a bridge server, for which you provide the valve spec, and the bridge client, which is returned
	; with its pipe-server-class setup by default.
	;
	; the client spec is used directly in the make call, so you can tweak the client before it gets
	; assigned a bridge server.
	;-----------------
	bridge: func [
		bridge-name [word!] ; '-client and '-server  are added to respective plug types.
		client-spec [block! none!]
		server-spec [block!]
		/local bridge client server-type client-type
	][
		server-type: to-word join to-string bridge-name "-server"
		client-type: to-word join to-string bridge-name "-client"
		
		bridge: make !plug server-spec
		
		bridge/pipe?: 'bridge
		
		bridge/valve/type: server-type
		
		client: make !plug any [client-spec []]
		client: make client [
			valve: make valve [
				pipe-server-class: bridge
				type: client-type
			]
		]
		client
	]
		


	;-  
	;-----------------------
	;- !PLUG
	;-----------------------
	!plug: make object! [
		;------------------------------------------------------
		;-    VALUES
		;------------------------------------------------------
		
		;-----------------------------------------
		;-       sid:
		;-----------------------------------------
		; a unique serial number which will never change
		;-----------------------------------------
		sid: 0	; (integer!)
		
		
		
		;-----------------------------------------
		;-       observers:
		;-----------------------------------------
		; who is using ME (none or a block)
		;-----------------------------------------
		observers: none
		
		
		;-----------------------------------------
		;-       subordinates:
		;-----------------------------------------
		; who am I using  (none or a block)
		;-----------------------------------------
		subordinates: none
		
		
		;-----------------------------------------
		;-       dirty?:
		;-----------------------------------------
		; has any item above me in the chain changed?
		; some systems will always set this back to false,
		; when they process at each change instead of deffering eval.
		;
		; v0.8.0 added the 'clogged state.  this is 
		;        defined as a dirty state within the
		;        node, but prevents any propagation
		;        from crossing the !plug, allowing
		;        for single refresh which doesn't
		;        cause the whole tree to become dirty.
		;
		;        usefull in controled environments
		;        especially to contain stainless?
		;        plugs to over reach observers which
		;        actually do not need to now about
		;        our own local refreshes.
		;
		; when plugs are new, they are obviously dirty.
		dirty?: True
		
		
		;-----------------------------------------
		;-       frozen?:
		;-----------------------------------------
		; this allows you to prevent a !plug from
		; cleaning itself.  the plug remains dirty
		; will never be processed.
		;
		; this is a very powerfull optimisation in many
		; circumstances.  We often know within a manager,
		; that a specific network has to be built before
		; it has any meaning (several links are needed,
		; data has to be piped, but isn't available yet, etc)
		; normaly, if any observer is stainless? or being
		; viewed dynamically, it will cause a chain reaction
		; which is ultimately useless and potentially slow.
		;
		; imagine a graphic operation which takes a second
		; to complete for each image linked... if you link
		; 5 images, you end up with a fibonacci curve of wasted time
		; thus 1 + 2 + 3 + 4 + 5 ... 13 operations, when only the last
		;  5 are really usefull!
		; as the data set grows, this is exponentially slow.
		;
		; if we freeze the node while the linking occurs,
		; and then unfreeze it, only one process is called,
		; with the 5 links.
		;
		; you could also use a function and let it react based
		; on conditions.
		;
		; nodes aren't frozen by default cause it would be tedious
		; to manage all the time, but use this when its 
		; worth it!
		frozen?: False
		
		
		;-----------------------------------------
		;-       stainless?:
		;-----------------------------------------
		; This forces the container to automatically regenerate content when set to dirty!
		; thus it can never be dirty...
		;
		; used sparingly this is very powerfull, cause it allows the end of a procedural
		; tree to be made "live".  its automatically refreshed, without your intervention :-)
		;-----------------------------------------
		stainless?: False
		
		
		;-----------------------------------------
		;-       pipe?:
		;-----------------------------------------
		;
		; pipe? is used to either determine if this liquid IS a pipe or if it is connected to one.
		;
		; v0.5.1 change: now support 'simple  as an alternative plug mode, which allows us to fill data
		; in a plug without actually generating/handling a pipe connection.  The value is simply dumped
		; in plug/liquid and purify may adapt it as usual
		;
		; This new behaviour is called containing, and like piping, allows liquids to store data
		; values instead of only depending on external inputs.
		;
		; This property will also change how various functions react, so be sure not to play around
		; with this, unless you are sure of what you are doing.
		;
		; by setting pipe? to True, you will tell liquid that this IS a pipe plug.  This means that the plug
		; is responsible for notifying all the subordinates that its value has changed.
		; it uses standard liquid procedures to alert piped plugs that its dirty, and whatnot.
		;
		; By setting this to a plug object, you are telling liquid that you are CONNECTED to a 
		; pipe, thus, our fill method will send the data to IT.
		;
		; note that you can call fill directly on a pipe, in which case it will fill its pipe clients
		; normally.
		;
		; also, because the pipe IS a plug, you can theoretically link it to another plug, but this 
		; creates issues which are not designed yet, so this useage is not encouraged, further 
		; versions might specifically handle this situation by design.
		;
		; v1.0.2 'simple pipes are relabeled 'container pipes
		;
		;-----------------------------------------
		pipe?: none
		
		;-----------------------------------------
		;-       mud:
		;-----------------------------------------
		; in containers/pipes: stores manually filled values
		;
		; in linked nodes: can be used as a cache for returning always the same series out of process...
		; basically, it would be equal to liquid, when there is no error, some other values otherwise.
		mud: none
		
		;-----------------------------------------
		;-       liquid:
		;-----------------------------------------
		; stores processing results (cached process) allows lazyness, since results are kept.
		; this is set by the content method using the return value of process
		liquid: none
		
		
		;-----------------------------------------
		;-       shared-states:
		;
		; deprecated (unused and slows down operation)
		;-----------------------------------------
		; this is a very special block, which must NOT be replaced arbitrarily.
		; basically, it allows ALL nodes in a liquid session to extremely 
		; efficiently share states.
		;
		; typical use is to prevent processing in specific network states
		; where we know processing is useless, like on network init.
		;
		; add  'init to the shared-states block to prevent propagation whenever you are
		; creating massive amounts of nodes. then remove the init and call cleanup on any leaf nodes
		;
		; the instigate func and clear func still work.  they are just
		; not called in some circumstances.
		;
		; making new !plugs with alternate shared-states blocks, means you can separate your
		; networks, even if they share the same base clases.
		;-----------------------------------------
		;shared-states: []
		
		
		
		;-       channel:
		; if plug is a channeled pipe, what channel do we request from our (bridged) pipe server?
		channel: none
		
		
		
		
		;-----------------------------------------
		;-       linked-container?:
		; DEPRECATED.
		;-----------------------------------------
		; if set to true, this tells the processing mechanisms that you wish to have both 
		; the linked data AND mud, which will be filtered, processed and whatever 
		; the mud will always be the last item on the list.
		linked-container: linked-container?: false
		
		
		;-----------------------------------------
		;-       resolve-links?:
		;-----------------------------------------
		; tells pipe clients that they should act as a normal
		; dependency plug even if receiving pipe events.
		;-----------------------------------------
		resolve-links?: none
		
		
		
		
		
		;------------------------------------------------------
		;-    VALVE (class)
		;------------------------------------------------------
		valve: make object! [
			;-        qualifiers:
			;-            *plug*
			; normally, we'd add a word in the definition like so... but its obviously useless adding
			; a word within all plugs
			; the value of the qualifier is a version, which identifies which version of a specific
			; master class we are derived from
			; ex:
			;
			; *plug*: 1.0  
			
			
			;--------------
			; class name (should be word)
			;-        type:
			type: '!plug
			
			;--------------
			; used to classify types of liquid nodes.
			;-        category:
			category: '!plug
			
			
			;-----------------
			;-        pipe-server-class:
			; this is set to !plug just after the class is created.
			; put the class you want to use automatically within you plug derivatives
			pipe-server-class: none
			
			
			
			
			
			
			;-      miscelaneous methods

			;---------------------
			;-        cycle?()
			;---------------------
			; check if a plug is part of any of its subordinates
			;---------------------
			cycle?: func [
				"checks if a plug is part of its potential subordinates, and returns true if a link cycle was detected. ^/^-^-If you wish to detect a cycle BEFORE a connection is made, supply observer as ref plug and subordinate as plug."
				plug "the plug to start looking for in tree of subordinates" [object!]
				/with "supply reference plug directly"
					refplug "the plug which will be passed along to all the subordinates, to compare.  If not set, will be set to plug" [block!]
				/debug "(disabled in this optimized release)  >>> step by step traversal of tree for debug purposes, should only be used when prototyping code"
				/local cycle? index len
			][
				cycle?: false

				; is this a cycle?
				either all [
					(same? plug refplug)
					0 <> plug/valve/links plug ; fix a strange bug in algorythm... cycle? must be completely revised
				][
					vprint/always "WARNING: liquid data flow engine Detected a connection cycle!"
					
					;print a bit of debugging info...
					vprint/always plug/valve/type
					vprint/always plug/valve/links plug
					
					cycle?: true
				][

					if none? refplug [
						refplug: plug
					]

					;does this plug have subordinates
					if plug/valve/linked? plug [
						index: 1
						len: length? plug/subordinates

						until [
							; <FIXME> quickfix... do MUCH more testing
							if object? plug/subordinates/:index [	
								cycle?: plug/subordinates/:index/valve/cycle?/with plug/subordinates/:index refplug
							]
							index: index + 1
							any [
								cycle?
								index > len
							]
						]
					]
				]

				refplug: plug: none


				cycle?
			]


			;---------------------
			;-        cycle?()
			;---------------------
			; check if a plug is part of any of its subordinates
			;---------------------
			cycle?: func [
				"checks if a plug is part of its potential subordinates, and returns true if a link cycle was detected. ^/^-^-If you wish to detect a cycle BEFORE a connection is made, supply observer as ref plug and subordinate as plug."
				plug "the plug to start looking for in tree of subordinates" [object!]
				/with "supply reference plug directly"
					refplug "the plug which will be passed along to all the subordinates, to compare.  If not set, will be set to plug" [block!]
				/debug "step by step traversal of tree for debug purposes, should only be used when prototyping error generating code"
				/local cycle? index len
			][
				if all [
					value? 'do-liquid-cycle-debug
					do-liquid-cycle-debug
				][
					debug: true
				]
				either debug [
					vin/always ["liquid/"  plug/valve/type  "[" plug/sid "]/cycle?" ]
				][
					vin ["liquid/"  plug/valve/type  "[" plug/sid "]/cycle?" ]
				]
				cycle?: false
				if debug [
					if refplug [
						vprint/always ["refplug/sid: " refplug/sid ]
					]
				]

				; is this a cycle?
				either (same? plug refplug) [
					vprint/always "WARNING: liquid data flow engine Detected a connection cycle!"
					cycle?: true
				][

					if none? refplug [
						refplug: plug
					]

					;does this plug have subordinates
					if plug/valve/linked? plug [
						if debug [
							vprint/always "-> press enter to move on cycle check to next subordinate"
							ask ""
						]
						index: 1
						len: length? plug/subordinates

						until [
							; <FIXME> quickfix... do MUCH more testing
							if object? plug/subordinates/:index [	
								cycle?: plug/subordinates/:index/valve/cycle?/with plug/subordinates/:index refplug
							]
							index: index + 1
							any [
								cycle?
								index > len
							]
						]
					]
				]

				refplug: plug: none

				either debug [
					vout/always
				][
					vout
				]

				cycle?
			]
			
			

			;---------------------
			;-        stats()
			;---------------------
			stats: func [
				"standardized function which print data about a plug"
				plug "plug to display stats about" [object!]
				/local lbls item vbz labels
			][
				vin/always/tags  ["liquid/"  type  "[" plug/sid "]/stats" ] [!plug stats]
				vprint/always/tags "================" [!plug stats]
				vprint/always/tags "PLUG STATISTICS:" [!plug stats]
				vprint/always/tags "================" [!plug stats]
				
				
				vprint/always/tags "LABELING:" [!plug stats]
				vprint/always/tags "---" [!plug stats]
				vprint/always/tags [ "type:      " plug/valve/type ] [!plug stats]
				vprint/always/tags [ "category:      " plug/valve/category ] [!plug stats]
				vprint/always/tags [ "serial id: " plug/sid] [!plug stats]
				
				
				vprint/always/tags "" [!plug stats]
				vprint/always/tags "LINKEAGE:" [!plug stats]
				vprint/always/tags "---" [!plug stats]
				vprint/always/tags ["total subordinates: " count plug/subordinates object! ] [!plug stats]
				vprint/always/tags ["total observers: " length? plug/observers  ] [!plug stats]
				vprint/always/tags ["total commits: " count plug/subordinates block! ] [!plug stats]
				if find plug/subordinates word! [
					vbz: verbose
					verbose: false
					lbls: plug/valve/links/labels plug
					labels: copy []
					foreach item lbls [
						append labels item
						append labels rejoin ["("  plug/valve/links/labeled plug item ")"]
					]
					verbose: vbz
					vprint/always/tags ["labeled links:  (" labels ")"] [!plug stats]
				]
				
				
				vprint/always/tags "" [!plug stats]
				vprint/always/tags ["VALUE:"] [!plug stats]
				vprint/always/tags "---" [!plug stats]
				either series? plug/liquid [
					;print "$$$$$$$$"
					vprint/always/tags rejoin ["" type?/word plug/liquid ": " copy/part mold/all plug/liquid 100 " :"] [!plug stats]
				][
					;print "%%%%%%%%"
					vprint/always/tags rejoin ["" type?/word plug/liquid ": " plug/liquid] [!plug stats]
				]
				
				
				vprint/always/tags "" [!plug stats]
				vprint/always/tags "INTERNALS:" [!plug stats]
				vprint/always/tags "---" [!plug stats]
				vprint/always/tags [ "pipe?: " any [all [object? plug/pipe? rejoin ["object! sid(" plug/pipe?/sid ")"]]	plug/pipe? ]] [!plug stats]
				vprint/always/tags [ "stainless?: " plug/stainless? ] [!plug stats]
				vprint/always/tags [ "dirty?: " plug/dirty? ] [!plug stats]
				;vprint/always/tags [ "shared-states: " plug/shared-states ] [!plug stats]
				vprint/always/tags [ "resolve-links?: " plug/resolve-links? ] [!plug stats]
				either series? plug/mud [
					vprint/always/tags [ "mud: "  copy/part mold/all plug/mud 100 ] [!plug stats]
				][
					vprint/always/tags [ "mud: " plug/mud ]  [!plug stats]
				]
				
				vprint/always/tags "================" [!plug stats]
				vout/always
			]


			;-      construction methods

			;---------------------
			;-        init()
			;---------------------
			; called on every new !plug, of any type.
			;
			;  See also:  SETUP, CLEANSE, DESTROY
			;---------------------
			init: func [
				plug "plug to initialize" [object!]
			][
				plug/sid: alloc-sid
				vin  ["liquid/"  type  "[" plug/sid "]/init" ]
			
				plug/observers: copy []
				plug/subordinates: copy []
				
				; this is a bridged pipe server
				if plug/pipe? = 'bridge [
					; this is persistent
					; each channel will be referenced with a select inside the liquid.
					;
					; example for a color bridge
					; [ R [25] G [50] B [0] A [200] RGB [25.50.0.200] ]
					; 
					plug/liquid: copy []
				]

				append plug-list plug/sid
				append plug-list plug

				setup plug
				cleanse plug

				; allow per instance init, if that plug type needs it.  Use as SPARINGLY as possible.
				if in plug 'init [
					plug/init
				]
				vout
			]
			

			;---------------------
			;-        setup()
			;---------------------
			;  IT IS ILLEGAL TO CALL SETUP DIRECTLY IN YOUR CODE.
			;
			; called on every NEW plug of THIS class when plug is created.
			; for any recyclable attributes, implement them in cleanse.
			; This function is called by valve/init directly.
			;
			; At this point (just before calling setup), the object is valid 
			; wrt liquid, so we can already call valve methods on the plug 
			; (link, for example)
			;
			;  See also:  INIT, CLEANSE, DESTROY
			;---------------------
			setup: func [
				plug [object!]
			][
			]


			;---------------------
			;-        cleanse()
			;---------------------
			; use this to reset the plug to a neutral and default value. could also be called reset.
			; this should be filled appropriately for plugs which contain other plugs, in such a case,
			; you should cleanse each of those members if appropriate.
			;
			; This is the complement to the setup function, except that it can be called manually
			; by the user within his code, whenever he wishes to reset the plug.
			;
			; init calls cleanse just after setup, so you can put setup code here too or instead. 
			; remember that cleanse can be called at any moment whereas setup will only 
			; ever be called ONCE.
			;
			; optionally, you might want to unlink the plug or its members.
			;
			;  See also:  SETUP, INIT, DESTROY
			;---------------------
			cleanse: func [
				plug [object!]
			][

				;plug/mud: none
				;plug/liquid: none ; this just breaks to many setups.  implement manually when needed.

				; cleanup pointers
				plug: none
			]



			;------------------------
			;-        destroy()
			;------------------------
			; use this whenever you must destroy a plug.
			; destroy is mainly used to ensure that any internal liquid is unreferenced in order for the garbage collector
			; to be able to properly recuperate any latent liquid.
			;
			; after using destroy, the plug is UNUSABLE. it is completely broken and nothing is expected to be usable within.
			; nothing short of calling init back on the plug is expected to work (usually completely rebuilding it from scratch) .
			;
			;  See also:  INIT SETUP CLEANSE
			;------------------------
			destroy: func [
				plug [object!]
			][
				plug/valve/unlink plug
				plug/valve/insubordinate plug
				plug/valve/detach plug
				plug/mud: none
				if plug/pipe? = 'bridge [
					clear head plug/liquid
				]
				plug/liquid: none
				plug/subordinates: none
				plug/observers: none
				plug/pipe?: none
				;plug/shared-states: none
				plug: first reduce [plug/sid plug/sid: none]
				if plug: find plug-list plug [
					remove/part plug 2
				]
				;voff
			]


			;-      plug connection methods
			;---------------------
			;-        link?()
			;---------------------
			; validate if plug about to be linked is valid.
			; default method simply refuses if its already in our subordinates block.
			;
			; Be carefull, INFINITE CYCLES ARE ALLOWED IF YOU REPLACE THIS FUNC
			;---------------------
			link?: func [
				observer [object!] "plug about to perform link"
				subordinate [object!] "plug which wants to be linked to"
			][
				
				either check-cycle-on-link? [
					
					; by default, plugs now do a verification of processing cycles
					; if you need speed and can implement the cycle call within the manager instead,
					; you can simply replace this func, but the above warning come into effect.
					; 
					; the cycle check slows down linkage but garantees prevention of deadlocks.
					not if cycle?/with subordinate observer [
						if liquid-error-on-cycle? [
							to-error "LIQUID CYCLE DETECTED ON LINK"
						]
						true
					]
				][true]
			]



			;---------------------
			;-        link()
			;---------------------
			; link to a plug (of any type)
			;
			; v0.5
			; if subordinate is a pipe, we only do one side of the link.  This is because 
			; the oberver connects to its pipe (subordinate) via the pipe? attribute.
			;
			; v0.5.4
			; we now explicitely allow labeled links and even allow them to be orphaned.
			; so we support  0-n number of links per label;
			;
			; v1.0.2 
			; complete rewrite, at least twice as fast.
			; does not manage pipes anymore.
			;
			; this actually means we can now LINK pipe servers and use them in resolve-links? mode.
			; this is very usefull with bridged pipes since it allows link TO data which are used 
			; as parameters for the bridging process().
			; 
			;---------------------
			link: func [
				observer [object!] "plug which depends on another plug, expecting liquid"
				subordinate [object! none! block!] "plug which is providing the liquid. none is only supported if label is specified. block! links to all plugs in block"
				/head "this puts the subordinate before all links... <FIXME> only supported in unlabeled mode for now"
				/label lbl [word! string!] "the label you wish to use if needing to reference plugs by name. "
				/exclusive  "Is the connection exclusive (will disconnect already linked plugs), cooperates with /label refinement, note that specifying a block and /explicit will result in the last item of the block being linked ONLY."
				;/limit max [integer!] limit-mode [word!] "<TO DO> NOT IMPLEMENTED YET !!! maximum number of connections to perform and how to react when limit is breached"
				/reset "Unpipes, unlinks the node first and IMPLIES EXCLUSIVE (label is supported as normal). This basically makes SURE the supplied subordinate will become the soul data provider and really will be used."
				/pipe-server "applies the link to our pipe-server instead of ourself.  we MUST be piped in some way."
				/local subordinates  plug ok?
			][
				ok?: true ; unless link? returns true, all is good.
				
				
				if pipe-server [
					unless observer: observer/valve/pipe observer [
						to-error "liquid/link(): /pipe-server requires some form of piping (container, pipes, bridge)."
					]
				]
				
				if reset [
					observer/valve/detach observer
					observer/valve/unlink observer
					either label [
						observer/valve/link/label observer subordinate lbl 
					][
						observer/valve/link observer subordinate
					]
					return
				]
				
				; when exclusive, we unlink all appropriate subordinates from observer
				if exclusive [
					either object? subordinate [
						either label [observer/valve/unlink/only observer lbl][observer/valve/unlink observer]
					][
						to-error "liquid/link(): exclusive linking expects a subordinate of type object!"
					]
				]
				
				; make sure we don't try to link an unlabeled subordinate to none!
				; its valid for labels to be none since it simply adds the label to the subordinates block if its not there yet.
				; we call these orphaned labels
				if all [none? subordinate not label ][
					to-error "liquid/link(): only /label linking supports none! type subordinate!"
				]
				
				subordinates: any [
					all [
						label
						
						; re-use label or create it.
						any [
							all [
								; find this label
								subordinates: find/tail observer/subordinates lbl
								any [
									; we should link at head, so don't search for end of label's links.
									all [head subordinates]
									
									; move at next word (thus the end of this label's subordinates)
									find subordinates word!
									
									; we didn't find a word, so we are the last one
									tail subordinates
								]
							]
							; create new label, return after insert (thus tail)
							; head = tail since its a new label, so we don't have to check for this condition.
							insert tail observer/subordinates lbl
						]
					]
					; not labeled, just get the tail of subordinates block
				 	tail observer/subordinates
				]
				
				
				; now that we are at our index (labeled or not), just link any subordinates we where given (ignoring nones)
				foreach subordinate compose [(subordinate)] [
					either link? observer subordinate [
						total-links: total-links + 1 ; a general stats value
						if subordinate [
							subordinates: insert subordinates subordinate
						]
					][
						ok?: false
						break
					]
					
					; subordinate has to know that we are observing it for propagation purposes.
					insert tail subordinate/observers observer
					
					; callback which allows plugs to perform tricks after being linked
					observer/valve/on-link observer subordinate
				]
				
				; whatever happens, make sure observer isn't clean.
				observer/valve/dirty observer
				

				 ok?

			]

			;-----------------
			;-        on-link()
			;-----------------
			; makes reacting to linking easier within sub-classes of !plug
			; 
			; this is called AFTER the link, so you can react to the link's position 
			; in the subordinates...  :-)
			;-----------------
			on-link: func [
				plug [object!]
				subordinate [object!]
			][
			]
			
			

			;---------------------
			;-        linked? ()
			;---------------------
			; is a plug observing another plug? (is it dependent or piped?)
			;---------------------
			linked?: func [
				plug "plug to verify" [object!]
				/only "does not consider a piped plug as linked, usually used when we want to go to/from (toggle) piped mode."
				/with subordinate [object!] "only returns true if we are linked with a specific subordinate"
				/local val
			][
				; not not converts arbitray values into booleans (only none and false return false)
				val: not not any [
					all [
						plug/subordinates
						not empty? plug/subordinates
						any [
							; any connection is good?
							not with
							; is the subordinate already linked?
							find plug/subordinates subordinate
						]	
					]
					all [not only object? plug/pipe?]
				]
				val
			]


			;---------------------
			;-        sub()
			;---------------------
			; returns specific links from our subordinates
			;---------------------
			sub: func [
				plug [object! block!]
				/labeled labl [word!] ; deprecated, backwards compatibility only.  do not use.  will eventually be removed
				/label lbl [word!]
				;/start sindex
				;/end eindex
				;/part amount
				/local amount blk src-blk
			][
				if labeled [lbl: labl label: true] ; deprecated, backwards compatibility only.  do not use.  will eventually be removed
				
				src-blk: any [
					all [block? plug plug]
					plug/subordinates
				]	
				
				either label [
					either label: find/tail src-blk lbl [
						unless amount: find label word! [ ; till next label or none (till end).
							amount: tail label
						]
						blk: copy/part label amount ; if they are the same, nothing is copied
					][
						blk: none
					]
				][
					blk: none
				]
				first reduce [blk src-blk: labeled: label: lbl: labl: amount: blk: none]
			]


			;---------------------
			;-        links()
			;---------------------
			; a generalized link querying method.  supports different modes based on refinements.
			;
			; returns the number of plugs we are observing
			;---------------------
			links: func [
				plug [object!] "the plug you wish to scan"
				/labeled lbl [word!] "return only the number of links for specified label"
				/labels "returns linked plug labels instead of link count"
				/local at lbls
			][
				either labels [
					either find plug/subordinates word! [
						foreach item plug/subordinates [
							if word! = (type? item) [
								lbls: any [lbls copy []]
								append lbls item
							]
						]
						lbls
					][none]
				][
					either labeled [
						either (at: find plug/subordinates lbl) [
							; count all objects until we hit something else than an object if and only if we find an object just past the label
							count/while/within at object! object! 2
						][
							; none is returned if the label is not in list
							none
						]	
					][
						count plug/subordinates object!
					]
				]
			]





			;---------------------
			;-        unlink()
			;---------------------
			; unlink myself
			; by default,  we will be unlinked from ALL our subordinates.
			;
			; note that as of v5.4 we support orphaned labels. This means we can have labels
			; with a count of 0 as their number of plugs.  This is in order to keep evaluation
			; and plug ordering intact even when replacing plugs.  many tools will need this, 
			; since order of connections can influence processing order in some setups.
			;
			; v.0.5.5 now returns the plugs it unlinked, makes it easy to unlink data, filter plugs
			;         and reconnect those you really wanted to keep.
			;---------------------
			unlink: func [
				plug [object!]
				/only oplug [object! integer! word!] "unlink a specifc plug... not all of them.  Specifying a word! will switch to label mode!"
				/tail "unlink from the end, supports /part (integer!) disables /only"
				/part amount [integer!] "Unlink these many plugs, default is all.  /part also requires /only or /tail ,  these act as a start point (if object! or integer!) or bounds (when word! label is given)."
				/label "actually delete the label itself if /only 'label is selected and we end up removing all plugs."
				/detach "call detach too, usefull to go back to link mode"
				/local blk subordinate count rval
			][
				
				
				if detach [
					plug/valve/detach plug
				]
				
				if linked? plug [
					rval: copy []
					if not part [
						amount: 1
					]
					if tail [
						; this activates tail-based unlinking with optional /part attribute
						only: true 
						oplug: (length? plug/subordinates) - amount + 1
					]
					either only [
						switch type?/word oplug [
							object! [
								if found? blk: find plug/subordinates oplug [
									rval: disregard/part plug blk amount
								]
							]

							integer! [
								; oplug is an integer
								; we should not be using labels in this case.
								
								rval: disregard/part plug (at plug/subordinates oplug) amount
							]
							
							none! [
								; only possible if /tail was specified
								vprint "REMOVING FROM TAIL!"
								
							]

							word! [
								if subordinate: find plug/subordinates oplug [
									lblcount: links/labeled plug oplug
									either part [
										; cannot remove more plugs than there are, can we :-)
										amount: min amount lblcount
									][
										; remove all links 
										amount: lblcount
									]
									
									; in any case, we can only remove the label if all links would be removed
									either all [
										label
										amount >= lblcount
									][
										; we must remove label and all its links
										remove subordinate
										rval: disregard/part plug subordinate amount
									][
										; remove all links but keep the label.
										; amount could be zero, in which case nothing happens.
										rval: disregard/part plug next subordinate amount
									]
								]
							]

						]
					][
						; we stop observing ALL our subordinates.
						foreach subordinate plug/subordinates [
							if object? subordinate [
								if (found? blk: find subordinate/observers plug) [
									remove blk
								]
							]
							append rval subordinate
						]
						; unlink ourself from all those subordinates
						clear head plug/subordinates
					]

					dirty plug
				]
				oplug: none
				plug: none
				
				rval
			]


			;--------------------
			;-        insubordinate()
			;
			; remove all of our observers.
			;--------------------
			insubordinate: func [
				""
				plug [object!]
				/local observer
			][
				if plug/observers [
					foreach observer copy plug/observers [
						observer/valve/unlink/only observer plug
					]
				]
			]


			;---------------------
			;-        disregard()
			;---------------------
			; this is a complement to unlink.  we ask the engine to remove the observer from
			; the subordinate's observer list, if its present.
			;
			; as an added feature, if the supplied subordinate is within a block, we
			; remove it from that block.
			;---------------------
			disregard: func [
				observer [object!]
				subordinates [object! block!]
				/part amount [integer!] "Only if subordinate is a block!, if amount is 0, nothing happends."
				/local blk iblk subordinate
			][
				either block? subordinates [
					subordinates: copy/part iblk: subordinates any [amount 1]
					remove/part iblk length? subordinates
				][
					subordinates: reduce [subordinates]
				]
				
				foreach subordinate subordinates [
					either object? subordinate [
						either (found? blk: find subordinate/observers observer) [
							remove blk
						][
							to-error rejoin ["liquid/"  type  "[" plug/sid "]/disregard: not observing specified subordinate ( " subordinate/sid ")" ]
						]
					][
						to-error rejoin ["liquid/"  type  "[" plug/sid "]/disregard: supplied subordinates must be or contain objects." ]
					]
				]
				blk: observer: subordinate: iblk: none
				subordinates
			]








			;-      piping methods



			;---------------------
			;-        new-pipe()
			;---------------------
			; create a new pipe plug.
			; This is a method, simply because we can easily change what kind of 
			; plug is generated in derived liquid classes.
			;
			; <TO DO>: auto destroy previous pipe if its got no more observers?
			;---------------------
			new-pipe: func [
				plug [object!]
				/channel ch [word!] "setup a channel directly"
				/using server-base [object!] "enforce a class of pipe-server"
				/local pipe-server
			][
				vin ["liquid/" plug/valve/type "[" plug/sid "]/new-pipe()"]

				; allocate pipe-server
				; if you want a custom pipe server class, just set it within the base class.
				pipe-server: make any [server-base plug/valve/pipe-server-class] [valve/init self]
				
				if none? pipe-server/pipe? [
					pipe-server/pipe?: true ; tells new plug that IT is a pipe server
				]
				
				if 'bridge = pipe-server/pipe? [
					vprint "pipe-server is a BRIDGE"
				]
				
				channel: any [ch plug/channel]
				either channel [
					vprint "CHANNELED pipe-server client"
					;vprint "I will FORCE this to be a bridge, even if it isn't one in pipe-class"
					; force pipe-server into being a bridge
					pipe-server/pipe?: 'bridge
					
					; this will call define-channel automatically.
					attach/to plug pipe-server channel
				][
					; note that attach will raise an error if you try to attach to a bridge and don't give it a channel.
					attach plug pipe-server ; we want to be aware of pipe changes. (this will also connect the pipe in our pipe? attribute)
				]
				vout
				pipe-server
			]




			;---------------------
			;-        pipe()
			;---------------------
			;---------------------
			pipe: func [
				"return pipe which should be filled (if any)"
				plug [object!] ; plug to get pipe plug from
				/always "Creates a pipe plug if we are not connected to one"
			][
				
				vin ["liquid/" plug/valve/type "[" plug/sid "]/pipe()"]
				vprint either always ["always force pipe"]["container fallback"]
				plug: any [
					all [not always (plug/pipe? = 'container) plug]
					all [(object? plug/pipe?) plug/pipe?]
					all [(plug/pipe? = true) plug]
					all [(plug/pipe? = 'bridge) plug]
					; the plug isn't piped in any way and we want to be sure it always has one.
					all [always plug/valve/new-pipe plug plug/pipe?]
				]
				
				vout
				plug
			]
			
			
			;-----------------
			;-        define-channel()
			;-----------------
			define-channel: func [
				plug [object!]
				channel [word!]
				/data value 
			][
				vin ["liquid/" plug/valve/type "[" plug/sid "]/define-channel()"]
				; make sure we are piped appropriately.
				either plug/pipe? = 'bridge [
					vprint mold to-lit-word channel
					; cannels are defined directly on the observers, as lists of observers, much like labeled subordinates.
					;
					; ex: [observers: [r [0] g [255] b [0] rgb [0.255.0]]]
					;
					; is the channel defined?
					unless block? blk: select plug/observers channel [
						append plug/observers reduce [channel copy []]
					]
					if data [
						plug/valve/fill/channel plug :value channel
					]
				][
					to-error "liquid/define-channel: cannot define channel, pipe server is not a bridge"
					; new-pipe will actually call define-channel via the attach/channel call, which calls us.
					; but it won't result in an endless loop, since by then (plug/pipe? = 'bridge) and our alternate block will trigger instead.
					;plug/valve/new-pipe/channel plug channel
				]
				vout
			]
			
			

			;---------------------
			;-        attach()
			;---------------------
			; this is the complement to link, but specifically for piping.
			;---------------------
			attach: func [
				""
				client [object!] "The plug we wish to pipe, can be currently piped or not"
				source [object!] "The plug which is or will be providing the pipe.  If it currently has none, it will be asked to create one, per its current pipe callback"
				/to channel [word!] "if pipe server is a bridge, which channel to attach to"
				/local blk pipe-server
			][
				
				vin ["liquid/" client/valve/type "[" client/sid "]/attach()"]
				;check if observer isn't currently piped into something
				client/valve/detach client
				
				

				; get the pipe we should be attaching to, covers all cases
				; if source doesn't have a pipe, it will get one generated as per its pipe-server-class,
				; that will be returned to us.
				pipe-server: source/valve/pipe/always source
				
				
				
				client/pipe?: pipe-server 
				
				;observer/valve/stats observer
				
				either pipe-server/pipe? = 'bridge [
					; pipe server is a bridge, we MUST supply a channel name
					unless channel [
						to-error "Liquid/attach(): pipe server is a bridge, channel name is required"
					]
					; remember which channel to request on content() call.
					client/channel: channel
					
					; make sure the channel exists on the pipe output
					pipe-server/valve/define-channel pipe-server channel
					either block? blk: select pipe-server/observers channel [
						append blk client
					][
						to-error "Liquid/attach(): pipe server is a bridge, and it was unable to define a channel"
					]
				][
					; a normal pipe broadcasts the same information to everyone on the pipe.
					append pipe-server/observers client
				]
				
				pipe-server/valve/dirty pipe-server
				vout
			]


			;---------------------
			;-        detach()
			;---------------------
			;
			; Unlink ourself from a pipe, causing it to stop messaging us (propagating). 
			; by default the plug will revert to dependency mode after being detached,
			; whatever pipe mode it was in (container, bridge, client)
			;
			; note that the /only refinement ensures that its previous value is preserved
			;
			; <TO DO> ? verify if the pipe server is then orphaned (not serving anyone) and in this case call destroy on it)
			;--------------------
			detach: func [
				plug [object!]
				/only "only unlinks from a pipe server (if any). if plug was piped or filled, it remains a container after. previous pipe value is kept."
				/local pipe channel was-piped? pval
			][
				was-piped?: not none? plug/pipe?
				
				; unlink, if any pipe
				if object? plug/pipe? [
					either word? plug/channel [
						if channel: select plug/pipe?/observers plug/channel [
							pval: any [
								all [plug/dirty? plug/mud]
								plug/liquid
							]
							if pipe: find channel plug [
								if only [
									pval: pipe/1/valve/content pipe/1
								]
								remove pipe
							]
						]
					
						plug/channel: none
					][
						if only [
							pval: plug/pipe?/valve/content plug/pipe?
						]
						if pipe: find plug/pipe?/observers plug [
							remove pipe
						]
					]
				]
				either all [
					only
					was-piped?
				][
					plug/pipe?: 'container
					; this MAY be problematic on some nodes with purification,
					; but they should be improved to cope with this feature.
					plug/mud: pval
					
					;we set the value of the pipe we where attached to
					plug/liquid: pval
					
				][
					plug/pipe?: none
				]
				pipe: plug: pval: none
			]
			
			
			;-----------------
			;-        on-channel-fill()
			; 
			; this is required by some bridges because there is interdependencies
			; between channels which aren't simple equivalents.
			;
			; the color example is a prime candidate since filling just a channel
			; will invariably depend on the "current" color.
			;
			; the current color may depend on a variety of sequenced fill calls, which might
			; not have been processed between calls to fill, because of lazyness.
			;
			; when called, mud is guaranteed to exist, so can be quickly retrived with:  data: first second plug/mud
			;-----------------
			on-channel-fill: func [
				pipe-server [object!]
			][
				vin [{on-channel-fill()}]
				; does nothing by default.
				data: first second pipe-server/mud
				v?? data
				vout
			]
			
			
			

			;---------------------
			;-        fill()
			;---------------------
			; If plug is not linked to a pipe, then it 
			; automatically connects itself to a new pipe.
			;---------------------
			fill: func [
				"Fills a plug with liquid directly. (stored as mud until it gets cleaned.)"
				plug [object!]
				mud ; data you wish to fill within plug's pipe
				/pipe "<TO DO> tells the engine to make sure this is a pipe, only needs to be called once."
				/channel ch "when a client sets a channel, it is sent to bridge using /channel name"
				/local pipe-server
			][
				vin ["liquid/" plug/valve/type "[" plug/sid "]/fill()"]

				; revised default method creates a container type plug, instead of a pipe.
				; usage indicates that piping is not always needed, and creates a processing overhead
				; which is noticeable, in that by default, two nodes are created and filling data needs
				; to pass through the pipe.  in most filling ops, this is not usefull, as all the
				; plug is used for is storing a value.
				;
				; a second reason is that from now on a new switch is being added to the plug,
				; so that plugs can be containers and still be linked.  this can simplify many types
				; of graphs, since graphs are often refinements of prior nodes.  so in that optic,
				; allowing us to use data and then modifying it according to local data makes
				; a lot of sense.
				
				
				; set channel to operate on. (none! by default)
				channel: any [ ch plug/channel ]
				
				;?? channel
				
				
				; NOTE: we enforce bridge pipe mode automatically when filling to a channel
				;       the channel will then be automatically created in the bridge.
				;
				; note that if the pipe-class-server doesn't really manage bridges, then 
				; it is re-built as a simple !plug server which, by default, returns stored values 
				; as if they where storage fields.  no processing or inter channel 
				; signaling will occur.  but all attached plugs will be propagated to.
				either channel [
					vprint "CHANNELED Fill"

					; if channel was supplied manually, apply it to plug right now.
					plug/channel: channel		
				
					vprobe plug/channel
					; make sure your pipe-server-class is a bridge
					; it will also make sure that a channel with plug/channel exists.
					pipe-server: plug/valve/pipe/always plug
					
					unless all [
						object? pipe-server: plug/pipe?
						pipe-server/pipe? = 'bridge
					][
						vprint "REPLACING PIPE SERVER WITH A !PLUG BRIDGE"
						plug/valve/new-pipe/channel/using plug channel !plug
					]
					pipe-server: plug/pipe?
				
					unless pipe-server/pipe? = 'bridge [
						to-error "liquid/fill(): cannot fill a channel, pipe is not bridged"
						
						; this is EVIL, but ensure liquid stability.
						; from this point on, the pipe server can only be attached to by channeled pipe clients.
						;
						; it also means that custom pipe servers not expecting to be used as bridges may CORRUPT
						; the liquid.
						;
						; the default plug, though, will hapilly return the channel as-is, so this default behaviour
						; is quite usefull.
						plug/pipe?: 'bridge
					]
					
					vprint "Defining Channel"
					;pipe-server/valve/define-channel pipe-server channel
					
					; in bridge-mode we need to remember WHO signals data, cause each
					; data source is interpreted differently by the bridge process()
					pipe-server/mud: reduce [channel reduce [mud]]
					
					pipe-server/valve/on-channel-fill pipe-server
				][
					; be carefull, if your pipe-class-server is a bridge and the plug doesn't have its 
					; channel set, an error will be raised eventually, since the bridge will require a channel name.
					pipe-server: any [
						; enforce this to be a pipe
						all [pipe plug/valve/pipe/always plug]
						
						; get our pipe (or ourself)
						all [plug/valve/pipe plug]
						
						; or convert this plug into a simple container
						all [plug/pipe?: 'container plug]
					]
					
					if pipe-server/pipe? = 'bridge [
						to-error "liquid/fill(): pipe-server is a bridge but no fill channel was specified"
					]
					pipe-server/mud: mud
				]
				pipe-server/valve/dirty pipe-server
				;plug/valve/dirty plug
				vout
				
				;probe pipe-server/mud
				
				; just a handy shortcut for some uses.
				mud
			]


			;-----------------
			;-        notify()
			;
			; a high-level function used to make sure any dependencies are notified of our changed state(s)
			;
			; sometimes using fill when the value is the same or just modified is overkill.
			;
			; this should be called instead of dirty() from the outside, since it will adapt to the plug being 
			; a pipe (or not) automatically without causing a refresh deadlock or infinite recursion.
			;
			; note, this doesn't work with bridged clients yet.  since they depend on fill's channel handling.
			;-----------------
			notify: func [
				plug
			][
				plug: any [
					plug/valve/pipe plug ; returns pipe, container or none
					plug
				]
				;probe type? plug/pipe?
				plug/valve/propagate plug
			]
			
			


			;---------------------
			;-        dirty()
			;---------------------
			; react to our link being set to dirty.
			;---------------------
			dirty: func [
				plug "plug to set dirty" [object!]
				/always "do not follow stainless? as dirty is being called within a processing operation.  prevent double process, deadlocks"
			][
				vin ["liquid/" plug/valve/type "[" plug/sid "]/dirty()"]
				; being stainless? forces a cleanup call right after being set dirty...
				; use this sparingly as it increases average processing and will slow
				; down your code by forcing every plug to process all changes,
				; all the time which is not needed unless you nead interactivity.
				;
				; it can be usefull to set a user observed plug so that any
				; changes to the plugs, gets refreshed in an interactive UI..
				vprint "DIRTY"
				
				either all[
					plug/stainless?
					not always
				][
					plug/dirty?: true
					cleanup plug
					if propagate? plug [
						propagate plug
					]
				][
					if propagate? plug [
						propagate/dirty plug
					]
				]
				
				; clean up
				plug: none
				vout
			]





			;---------------------
			;-        instigate()
			;---------------------
			;
			; Force each subordinate to clean itself, return block of values of all links.
			;
			; v1.0.2 - instigate semantic change.  
			;
			;  -instigate now ignores links when the node is piped
			;  -pipe? now manages 3 different modes.  it would be wasted to handle it in cleanup AND in instigate.
			;
			; following method does not cause subordinate processing if they are clean :-)
			;---------------------
			instigate: func [
				""
				plug [object!]
				/local subordinate blk
			][
				vin ["liquid/" plug/valve/type "[" plug/sid "]/instigate()"]
				blk: copy []
				if linked? plug [
					;-------------
					; piped plug
					either object? plug/pipe? [
						; ask pipe server to process itself
						append/only blk (plug/pipe?/valve/cleanup plug/pipe?)
					][
						;-------------
						; linked plug
						; force each input to process itself.
						foreach subordinate plug/subordinates [
							switch/default type?/word subordinate [
								object! [
									append/only blk  subordinate/valve/cleanup subordinate
								]
								word! [
									; here we make the word pretty hard to clash with. Just to make instigation safe.
									; otherwise unobvious word useage clashes might occur, 
									; when actual data returned by links are words
									; use objectify func for easier (slower) access to this block
									append/only blk to-word rejoin [subordinate '=]
								]
								none! [
									append blk none
								]
							][
								to-error rejoin ["liquid sid: [" plug/sid "] subordinates block cannot contain data of type: " type? subordinate]
							]
						]
					]
					
					; clean up
					subordinate: none
					plug: none
				]
				; clean return
					
				vout
				blk
			]


			;-----------------
			;-        propagate?()
			;-----------------
			; should this plug perform propagation?
			; some optmized nodes can take advantage of linkeage data, streaming, internal
			; states to forego of propagation to observers, which greatly enhances efficiency
			; of a network.
			;-----------------
			propagate?: func [
				plug
			][
				true
			]
			
			



			;---------------------
			;-        propagate()
			;---------------------
			; cause observers to become dirty
			;---------------------
			propagate: func [
				plug [object!]
				/dirty "set us to dirty at time of propagation, dirty calls us with this flag"
				/local observer observers
			][
				vin ["liquid/" plug/valve/type "[" plug/sid "]/propagate()"]
				;unless plug/dirty? [ask "propagate clean"]
				;if plug/dirty? [return]
				;prin "."
				
				
				; tell our observers that we have changed
				; some plugs will then process (stainless), other will
				; just acknowledge their dirtyness and return.
				;
				; v0.5 change
				; do not dirty the node if it is piped and we are not its pipe.
				;
				; v0.6 change:
				; now supports linked-containers (was a lingering bug) where they would never get dirty
				; 
				; v0.7 extension:
				; support frozen?
				;
				; v1.0.1
				; we don't propagate if already dirty, an immense processing optimisation.
				;
				; v1.0.2 
				; rebuilt the whole algorithm, added support for bridged pipes
				unless any [plug/dirty? plug/frozen?] [
					if dirty [
						plug/dirty?: true
					]
					switch/default plug/pipe? [
						bridge [
							foreach [channel observers] plug/observers [
								foreach observer observers [
									; make sure we ignore piped clients which aren't part of that pipe
									; its actually a linking error.
									if any [
										none? observer/pipe?
										same? plug observer/pipe?
									][
										observer/valve/dirty observer
									]
								]										
							]
						]
						
						true [
							foreach observer plug/observers [
								; make sure we ignore piped clients which aren't part of that pipe
								; its actually a linking error.
								if any [
									none? observer/pipe?
									same? plug observer/pipe?
								][
									observer/valve/dirty observer
								]
							]
						]
					][
						foreach observer plug/observers [
							observer/valve/dirty observer
						]
					]
						
				]
				vout
			]


			;----------------------
			;-        stream()
			;----------------------
			; v0.8.0 new feature.
			; this allows a node to broadcast a message just like propagation, but
			; instead of handling container dirtyness, an acutal message packet is 
			; sent from node to node depth first, in order of observer links
			;
			; any node down the chain can inspect the message and decide if he wants 
			; to handle it.  in such a case, he will decide if the handling may
			; interest children or not. he may mutate the message, or add a return element
			; to it, and simply return. any node which detects the return element in the
			; message must simply stop propagating the message, cause it has been detected
			; and is a single point reply (only one node should reply).
			;
			; in the case where the stream is meant as an accumulator, the return message 
			; may simply include a new element which starts by 'return- (ex: 'return-size)
			; this will not provoke an arbitrary propagation end.
			;
			; it is good style (and actually suggested) that you use the plug's type name
			; within the message element and accumulator-type return values because 
			; it ensures the element names does not conflict with other plug authors msg.
			;
			; the stream message format is as follows.
			;
			; [ ; overall container
			;     'plugtype [plug/sid 'tag1: value1 'tag2: value2 ... 'tagN: valueN ] ; first message packet
			;     'plugtype [plug/sid 'tag1: value1 'tag2: value2 ... 'tagN: valueN ] ; second  message packet
			;     'plugtype [plug/sid 'tag1: value1 'tag2: value2 ... 'tagN: valueN ] ; third  message packet
			;     ...
			;     'return [return-plug/sid 'tag1: value1 'tag2: value2 ... 'tagN: valueN ]  ; return message (only one)
			; ]
			;
			; using the sid instead of a plug pointer limits the probability of memory sticking 
			; within the GC, uses less ram, and is MUCH more practical cause you can print the message.
			;
			;
			; RETURNS true if streaming should end
			;----------------------
			stream: func [
				plug [object!]
				msg [block! ] "Msg is SHARED amongst all observers"
				/init "Contstruct the initial message using msg as the message content"
				/as name "Alternate name for the message packet label (only used with init)"
				/depth dpt "Only go so many observers deep."
				/local end?
			][
				end?: false
				if init [
					name: any [name plug/valve/type]
					insert head msg plug/sid 
					msg: reduce [name msg]
				]
				; on-stream returns true if we should end streaming.
				either plug/valve/on-stream plug msg [
					end? true
				][
					either plug/frozen? [
						end? true
					][
						dpt: any [dpt - 1 1024]
						
						if dpt >= 0 [
							; we just reuse the init word, to s0ve from allocating an extra word for nothing
							foreach init plug/observers [
								if init/valve/stream/depth init msg dpt [
									end?: true
									exit ; stop looking for the end, we got it.
								]
							]
						]
					]
				]
				
				; end streaming?
				end?
			]
			
			;---------------------
			;-        on-stream()
			;----------------------
			; 
			;----------------------
			on-stream: func [
				plug [object!]
				msg [block! ]
			][
				
				; end streaming?
				false
			]
			
			
			
			;------------------------------------------------------------------------------------------------------------------
			;
			;-      computing methods
			;
			;------------------------------------------------------------------------------------------------------------------


			;---------------------
			;        filter()
			;---------------------
			; this is a very handy function which influences how a plug processes.
			;
			; basically, the filter analyses any expectations about input connection(s).  by looking at the 
			; instigated values block it receives.
			;
			; it will then return a block of values, if expectations are met. Otherwise, 
			; it returns none and computing does not occur afterwards.
			;
			; note that you are allowed to change the content of the block, by adding values, removing,
			; changing them, whatever.  The only requirement is that process must use the filtered values as-is.
			;
			; note that if a plug is piped, this function is never called.
			;
			; in the case of resolve-links? the function is now called, and so you can fix it as normal.
			;
			; eventually, returning none might force purify to propagate the stale state to all dependent plugs
			;
			; v1.0.2 deprecated
			;---------------------
;			filter: func [
;				plug [object!] "plug we wish to handle."
;				values [block!] "values we wish to filter."
;				/local tmpplug
;			][
;				if object? plug/pipe? [to-error "FILTER() CANNOT BE CALLED ON A PIPED NODE!"]
;					
;				; Do not forget that we must return a block, or we wont process.
;				;
;				; <FIXME>:  add process cancelation in this case (propagate stale?) .
;				values 
;			]




			;---------------------
			;-        process()
			;---------------------
			; process the plug's liquid
			;---------------------
			process: func [
				plug [object!]
				data [block!] "linked data to process (linked containers include the mud as well)"
				/channel [word!] ch "if this is a bridge, what channel caused processing"
			][
				either ch [
					; empty, safe list
					plug/liquid: []
					vprint "DEFAULT BRIDGE PROCESOR"
				][
					; get our subordinate's liquid
					plug/liquid: data/1
				]

			]





			;---------------------
			;-        purify()
			;---------------------
			; purify is a handy way to fix the filled mud, piped data, or recover from a failed process.
			; basically, this is the equivalent to a filter, but AFTER all processing occurs.
			;
			; we can expect plug/liquid to be processed or in an error state, if anything failed.
			;
			; when the plug is a pipe server, then its a chance to stabilise the value before propagating it 
			; to the pipe clients.  This way you can even nullify the fill and reset yourself 
			; to the previous (or any other value).
			;
			; eventually, purify will propagate the stale status to all dependent plugs if it is not
			; able to recover from an error, like an unfiltered node or erronous piped value for this plug.
			;
			; Note that the stale state can be generated within purify if its not happy with the current value
			; of liquid, even if it was called without the /stale refinement.
			;
			; we RETURN if this plug can be considered dirty or not at this point. 
			;---------------------
			purify: func [
				plug [object!]
				/stale "Tells the purify method that the current liquid is stale and must be recovered or an error propagated"
			][
				if stale [
					;print "plug is stale!:"
					; <FIXME> propagate stale state !!!
				]
				;print ["purify: "sid " : " (not none? stale) " " plug/liquid]
				; by default we will only stay dirty if stale was specified.
				; this allows us to make filter blocks which do not process until credentials
				; are met and the plug will continue to try to evaluate until its 
				; satisfied.
				(not none? stale)
			]



			;---------------------
			;-        cleanup()
			;---------------------
			; processing manager, instigates our subjects to clean themselves and causes a process
			; ONLY if we are dirty. no point in reprocessing our liquid if we are already clean.
			;
			; v1.0.3 completely rebuilds the whole function,
			;        it now supports bridges and is faster than previous versions.
			;---------------------
			cleanup: func [
				plug [object!]
				/channel ch [word!]
				/local data oops! mud pipe
			][
				;vin ["liquid/" plug/valve/type "[" plug/sid "]/cleanup()"]
				unless any [not plug/dirty? plug/frozen?] [

;					modes:
;					-----------
;					dependency:  pipe? is none
;					
;					pipe-server:  pipe? is true
;					
;					pipe-client:  pipe? is object
;					
;					bridge-server: pipe? is 'bridge
;
;					bridge-client: pipe? is object + ch is word
;					
;					container: pipe is 'simple
;					
;					linked container: pipe is 'simple + linked-container is true

					;------------------------
					; manage MUD
					;
					; mud is the data set when using fill()
					;------------------------
					;  we verify if we are piped in any way.
					;if pipe: plug/pipe? [
					pipe: plug/pipe?
						;vprint ["plug/pipe is set as: " type? pipe]
						case [
							; a dependency node.
							none? pipe [
								;vprint "DEPENDENCY"
								data: plug/valve/instigate plug
								plug/valve/process plug data
							]
							
							; a simple container.
							'container = pipe [
								;probe plug/valve/type
								;probe "simple container"
								;probe plug/resolve-links?
								either plug/resolve-links? [
									data: plug/valve/instigate plug
									data: head insert/only data plug/mud
									either plug/channel [
										plug/valve/process/channel plug data channel
									][
										plug/valve/process plug data
									]
								][
									plug/liquid: plug/mud
								]
							]
							
							; this is a pipe server, just use our mud
							true = pipe [
								either plug/resolve-links? [
									data: plug/valve/instigate plug
									data: head insert/only data plug/mud
									either plug/channel [
										plug/valve/process/channel plug data channel
									][
										plug/valve/process plug data
									]
								][
									plug/liquid: plug/mud
								]
							]
							
							; we are a pipe client, get its data
							object? pipe [
								either plug/channel [
									;vprint "channeled client"
									;vprint ["required channel: " plug/channel]
									plug/liquid: pipe/valve/cleanup/channel pipe plug/channel
									;vprint "liquid received: "
									;vprobe plug/liquid
								][
									plug/liquid: pipe/valve/cleanup pipe
								]
							]
							
							; a bridge server
							'bridge = pipe [
								;vprint "this is a bridge server"
								; the channel will be used in the process call.
								;
								; if channel is none, we either ignore the change, or use it within process.
								;
								; NOTE: the channel at this point is the last modified (filled) channel, 
								;       NOT a channel supplied to cleanup with /channel ch.
								channel: any [
									all [
										block? plug/mud 
										first plug/mud
									]
									; we provide a default which indicates that it wasn't explicitely set.
									; the actual bridge is responsible for handling this how it wants.
									'*unset
								]
								
								; the channel values are wrapped within blocks to ensure word values aren't mis-interpreted as
								; channel names.  (this is why we use first)
								;mud: first second plug/mud
								mud: any [
									all [
										block? plug/mud
										
										; we return the block, this allows the process to make the difference between
										; a none value and an unset channel eval.
										second plug/mud
									]
									
									; in an unset channel, the plug/mud is undefined, and its the 
									; bridge to manage inconsistencies.
									plug/mud
								]
								
								; this is a very advanced setup where the pipe SERVER is also linked !
								either plug/resolve-links? [
									data: plug/valve/instigate plug
									data: head insert/only data mud
								][
									data: reduce [mud]
								]
								
								; process the channels if required
								plug/valve/process/channel plug data channel
								
								;vprint "RESULT: "
								;vprobe plug/liquid
							]
						]
					;]
					
;					; instigate links ?
;					either any [
;						; simple dependency node
;						none? pipe
;						
;						; force processing even when used as part of container/pipe/bridge
;						plug/resolve-links?
;					][
;						vprint "LINKS TO RESOLVE"
;						; force dependency cleanup
;						data: plug/valve/instigate plug
;					][
;						; simple piping just sets the value within the client.
;						plug/liquid: mud
;					]
;
;					if data [
;						if pipe [
;							data: head insert/only data mud
;						]
;						
;						; process is responsible for playing with liquid
;						plug/valve/process plug data
;					]
;


					;------
					; allow a node to fix the value within plug/liquid to make sure its always within 
					; specs, no matter how its origin (or lack thereoff)
					;------
					;print "^/----->:"
					plug/dirty?: plug/valve/purify plug

					; this has to be set AFTER purify
					if all [
						plug/resolve-links? 
						in plug 'previous-mud
					][
						; allows you to compare new value, possibly to ignore multiple fill with different data
						plug/previous-mud: plug/mud
					]
				
				]
				
				rval: either ch [
					;probe "CHANNEL SPECIFIED"
					;if word! =  type? plug/pipe? [
					;	probe plug/pipe?
					;]
					;?? ch
					;probe plug/valve/type
					;probe plug/liquid
					;probe plug/valve/type
					;probe type? plug/liquid
					either function? channel: select plug/liquid ch [
						; this is an optimisation where a liquid will actually not compute
						; all channels at process time, but rather only on demand.
						channel plug
					][
						pick channel 1
					]
				][
					plug/liquid
				]
				;vout
				rval
			]



			;---------------------
			;-        content()
			;---------------------
			; method to get plug's processed value, just a more logical semantic value
			; when accessing a liquid from the outside.
			;
			; liquid-using code should always use content, whereas the liquid code itself
			; should always use cleanup.
			;
			; optionally you could redefine the function to make internal/external
			; plug access explicit... maybe for data hidding purposes, for example.
			;---------------------
			content: :cleanup
		]
	]
	
	; we use ourself as the basis for pipe servers by default.
	!plug/valve/pipe-server-class: !plug
]





;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %liquid.r 
    date: 23-Jun-2010 
    version: 1.0.5 
    slim-name: 'liquid 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: LIQUID
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: GLOB  v1.0.0
;--------------------------------------------------------------------------------

append slim/linked-libs 'glob
append/only slim/linked-libs [


;--------
;-   MODULE CODE



slim/register/header [

	; these are declared, in order for slim to set them within the glob lib. 
	; otherwise they pollute the global context.
	liquify: none
	content: none
	!plug: none
	fill: none
	link: none
	retrieve-plug: none

	;core: slim/open 'core none
	
	;- LIBS
	;gl: slim/open 'glayout 0.4.16
	ld: lqd: slim/open/expose 'liquid none [!plug liquify fill content link retrieve-plug]
	;glue: slim/open 'glue none


	;- FUNCTIONS
	;--------------------
	;-    --init--()
	;--------------------
	--init--: func [
		""
	][
		vin/tags ["Glob/--init--()"] [--init--]
		
		vout/tags [--init--]
		true
	]
	
	
	
	;--------------------
	;-    to-color()
	;--------------------
	to-color: func [
		""
		value [integer!]
	][
		; the 'REVERSE is for litle endian system...
		0.0.0.0 + to-tuple next reverse third make struct! [int [int]] reduce [value ]

		;<FIXME>
		; return big endian value on big-endian system
	]
	
	;--------------------
	;-    to-sid()
	;--------------------
	to-sid: func [
		""
		value [tuple! none!]
	][
		if tuple? value [
			if 4 <= length? value [value: make tuple! reduce [value/1 value/2 value/3]]
			to-integer to-binary value
		]
	]

	;--------------------
	;-    vlength()
	;--------------------
	vlength: func [v] [v: v * v square-root v/x + v/y]

	
	
	;--------------------
	;-    point()
	;--------------------
	point: func [
		{compute the specified point on the line}
	 	start [pair!]
		end [pair!]
		at [decimal! integer!]
		/bounded {truncates at if it ends up being larger than vector, note does not support negative at}
		/local vector points 
	] [
		; solve "degenerate case" first
		if equal? start end [return start]
		vector: end - start
		 
		if integer? at [
			; convert AT to decimal
			at: at / (to-integer vlength vector)
		]
		
		if all[
			bounded 
			at > 1.0
		][
			return end
		]
		
		; compute from end (instead of start)
		if negative? at [
			at: 1 + at
		]
		
		start + to-pair reduce [to-integer vector/x * at to-integer vector/y * at] 
	]
	
	;--------------------
	;-    segment()
	;--------------------
	segment: func [
		{compute the specified segment from the line}
	 	start [pair!]
		end [pair!]
		from [decimal! integer! none!]
		to  [decimal! integer! none!]
		/local vector points length
	][
		; solve "degenerate case" first
		if equal? start end [return reduce [start start]]
		vector: end - start
		length: vlength vector
		
		;---------- 
		;  FROM
		if integer? from [
			; convert from to decimal
			from: from / length
		]
		if none? from [
			from: 0
		]
		if negative? from [
			; this case lets us define a segment using the end as the reference
			from: 1 + from ; from is negative, so this actually substracts from length
		]
		
		;---------- 
		;  TO
		if integer? to [
			; convert to, to decimal
			to: to / length 
		]
		if none? to [
			to: 1
		]
		if negative? to [
			; this case lets us define a segment using the end as the reference
			to: 1 + to ; to is negative, so this actually substracts from length
		]
		reduce [start + to-pair reduce [to-integer vector/x * from to-integer vector/y * from] start + to-pair reduce [to-integer vector/x * to to-integer vector/y * to] ]
	]
	
	sizer-face: make face [ size: 1000x200 edge: none para: none font: none]
	;?? sizer-face
	;ask "..."
	
	;--------------------
	;-    sizetext()
	;--------------------
	sizetext: func [
		""
		text 
		font
	][
		sizer-face/font: font
		sizer-face/text: text
		
		;?? sizer-face
		
		size-text sizer-face
	]
	
	;-  
	;------------------------
	;- intypes
	;------------------------
	intypes: context [
		;linked-container?: true
		;-    !any
		!any: make lqd/!plug [
			valve: make valve [
				type: 'glob-intype-any
				
				linked-container?: false
				
				datatype: none
				
				;--------------------
				;-       purify()
				;--------------------
				purify: func [
					""
					plug [object!]
				][
					vin/tags ["glob/intypes["plug/sid"]/purify()"] [purify]
					if datatype [
						unless (type? plug/liquid) = datatype [
							;print "GLOB TYPE MISMATCH"
							;probe plug/liquid
							;probe datatype
							plug/liquid: switch/default to-word plug/valve/datatype [
								string! [
									;print "STRING!"
									either none? plug/liquid [
										""
									][
										mold plug/liquid
									]
								]
							][
								;probe plug/valve/datatype
								any [
									attempt [make datatype plug/liquid]
									attempt [make datatype none]
								]
							]
						]
					]
					
					vout/tags [purify]
					false
				]
				
				;--------------------
				;-    cleanse()
				;--------------------
				cleanse: func [
					""
					plug
				][
					vin/tags ["!intypes/[" plug/sid "]cleanse()"] [cleanse]
					;new-pipe plug
					if datatype [
						fill plug switch to-word datatype [
							pair! [
								0x0
							]
							tuple! [
								random 255.255.255
							]
							integer! [
								1
							]
							block! [
								copy []
							]
							string! [
								copy ""
							]
						]
					]
					vout/tags [cleanse]
				]
				
			]
		]
		
		;-    !pair
		!pair: make !any [
			valve: make valve [
				type: 'glob-intype-pair
				datatype: pair!
				purify: func [
					plug 
				][
					;print ["pair: " plug/liquid]
					false
				]
			]
		]
		
		
		
		;-    !color
		!color: make !any [
			valve: make valve [
				type: 'glob-intype-color
				datatype: tuple!
			]
		]
		
		;-    !integer
		!integer: make !any [
			valve: make valve [
				type: 'glob-intype-integer
				datatype: integer!
			]
		]
		
		;-    !decimal
		!decimal: make !any [
			valve: make valve [
				type: 'glob-intype-decimal
				datatype: decimal!
			]
		]
		
		;-    !bool
		!bool: make !any [
			valve: make valve [
				type: 'glob-intype-bool
				datatype: logic!
			]
		]
		
		;-    !block
		!block: make !any [
			valve: make valve [
				type: 'glob-intype-block
				datatype: block!
			]
		]
		;-    !state
		!state: make !any [
			valve: make valve [
				type: 'glob-intype-state
				datatype: logic!
			]
		]
		;-    !time
		!time: make !any [
			valve: make valve [
				type: 'glob-intype-time
				datatype: time!
			]
		]
		;-    !date
		!date: make !any [
			valve: make valve [
				type: 'glob-intype-date
				datatype: date!
			]
		]
		;-    !string
		!string: make !any [
			valve: make valve [
				type: 'glob-intype-string
				datatype: string!
			]
		]
		;-    !word
		!word: make !any [
			valve: make valve [
				type: 'glob-intype-word
				datatype: word!
			]
		]
	]
		
	
	
	
	;-  
	;------------------------
	;- !GEL
	;------------------------
	!gel: make lqd/!plug [
		draw-spec: none
		
		plug-sid: none
		
		; points to the glob this gel is included in.
		glob: none
		
		valve: make valve [
			type: '!gel
			category: '!gel
			
			;--------------------
			;-    cleanse()
			;--------------------
			cleanse: func [
				""
				gel [object!]
			][
				vin/tags ["!gel[" gel/sid "]/cleanse()"] [cleanse]
				gel/liquid: copy []
				;plug/input/offset/valve/fill plug/input/offset 0x0
				vout/tags [cleanse]
			]
			
			
			;--------------------
			;-    destroy()
			;--------------------
			destroy: func [
				""
				plug
			][
				vin/tags ["!gel/destroy()"] [destroy]
				plug/draw-spec: none ; this is a shared value with the glob. do not clear it.
				plug/glob: none
				
				!plug/valve/destroy plug
				vout/tags [destroy]
			]


						
			
			;--------------------
			;-    process()
			;--------------------
			process: func [
				""
				gel [object!]
				data [block!]
				/local plug tmp value blk offset pos size clr
			][
				vin/tags ["!gel[" gel/sid "]/process()"] [process]
				clear gel/liquid
				
				append gel/liquid compose/deep bind/copy gel/draw-spec 'data
				
				vout/tags [process]
			]
			


;			;--------------------
;			;-    blocking-state()
;			;--------------------
;			blocking-state: func [
;				"This allows you to define states in which the node will not propagate dirtyness.  This can be usefull to prevent useless computing when some input is not actually contributing to output in some specific states.  A possible future api extension being researched "
;				plug [object!]
;			][
;				vin/tags ["blocking-state()"] [ !glob blocking-state]
;				
;				
;				vout/tags [!glob blocking-state]
;				
;				;return true if we are in a blocking state.  This might even be a manually locked eventually.
;				; defaults to false, unless we really have a reason to block.
;				false
;			]
			
			;blocking-state: none ; just a faster alternative nop... but keep the spec above.

;			;--------------------
;			;-    instigate()
;			;--------------------
;			instigate: func [
;				""
;				plug
;			][
;				print "INSTIGATING!"
;				probe !plug/valve/instigate plug
;			]

;			;---------------------
;			;-    propagate
;			;---------------------
;			; cause observers to become dirty
;			;---------------------
;			propagate: func [
;				plug [object!]
;			][
;				vin/tags ["glob/"  type  "[" plug/sid "]/propagate" ] [ !glob propagate]
;				either blocking-state plug [
;					print "BLOCKING!"
;				][
;					!plug/valve/propagate plug
;				]
;				vout/tags [!glob propagate]
;			]
		]
	]		
	
		
	;-  
	;------------------------
	;;- !STACK
	;------------------------
	!stack: make lqd/!plug [
		linked-container?: true  ; the container data is the !stack parameters if they are not linked
		
		; store compiled layers
		layers: none
		
		valve: make valve [
			type: '!stack
			category: '!stack
			

			;--------------------
			;-    cleanse()
			;--------------------
			cleanse: func [
				""
				plug [object!]
			][
				vin/tags ["!glob[" plug/sid "]/cleanse()"] [cleanse]
				plug/liquid: copy []
				plug/layers: copy []
				;plug/input/offset/valve/fill plug/input/offset 0x0
				vout/tags [cleanse]
			]
			
			
			
			;--------------------
			;-    destroy()
			;--------------------
			destroy: func [
				""
				plug
			][
				vin/tags ["!stack/destroy()"] [destroy]
				clear head plug/layers
				plug/layers: none
				!plug/valve/destroy plug
				vout/tags [destroy]
			]


			
			;--------------------
			;-    get-items()
			;--------------------
			get-items: func [
				""
				blk
				lbl
				/local rblk
			][
				if rblk: find blk lbl [
					rblk: copy/part next rblk any [
						find next rblk word!
						tail rblk
					]
				]
				rblk
			]

		
		
			;--------------------
			;-    process()
			;--------------------
			process: func [
				""
				plug [object!]
				data
				/local blk layer
			][
				vin/tags ["!stack[" plug/sid "]/process()"] [process]
				clear head plug/liquid
				foreach layer data [
					append plug/liquid layer
				]
				vout/tags [process]
			]

			
		]
	]	
	
	;-  
	;------------------------
	;- !GLOB
	;------------------------
	!glob: make lqd/!plug [
		;----
		;-  input:
		input: none
		
		;----
		;-  linked-container?:
		; <TO DO> set this to false by default... should drastically improve load performance for large networks...
		linked-container?: true  ; this contains a single graphic definition which is then output in two blocks
		
		;----
		;-  clr-bak:
		clr-bak: red

		;----
		;-  drag-origin:
		drag-origin: 0x0
		
		;----
		;-  layers:
		; this is a list of !gel nodes, one for each layer
		; stack will link their own layer nodes to these nodes.
		; the glob will no long connect itself to the inputs, but rather will connect its layers to them.
		layers: none
		
		;----
		;-  draw-spec:
		; use the reflect() in the valve to set layers to use as outputs.
		draw-spec: none
		
		;----
		;-  reflection:
		; intermediate node which pipes dirty messages and compiles draw blocks from internal layers.
		reflection: none
	
		;----
		;-   VALVE:
		valve: make valve [
			type: '!glob
			category: '!glob
			
			; 
			;-    input-spec:
			input-spec: none
			
			;-    gel-spec:
			gel-spec: none
			
			
			;-----------------
			;-    reflect()
			;-----------------
			; setup the glob so that its content is set to reflect the contents of
			; selected layers.  this is sort of a hack, since an internal plug is created
			; which will propagate dirty messages to the glob.
			;
			; the glob, when asked for its content, will then actually refer to the reflection plug
			; and set itself to that data.
			;
			; this setup allows a glob to autonomously output its content, without the need for a complex
			; external viewport-like node.
			;-----------------
			reflect: func [
				glob [object!] "plug to reflect"
				layers [block! integer! none!] "a list or single layer to reflect, none removes the reflection"
				/local glob* layer
			][
				vin ["!glob[" glob/sid "]/reflect()"]
				
				either layers: all [layers compose [(layers)]] [
					vprint "Setting up reflection"
					unless object? glob/reflection [
						vprint "Creating new reflection"
						glob*: glob 
						glob/reflection: liquify/with !plug [
							;stainless?: true
							glob: glob*
							valve: make valve [
								type: '!reflection
								;-----------------
								;-        propagate?()
								;-----------------
								; we are using this function outside of its intended use, as a callback.
								; since we return true, its still valid.
								;
								; this function will propagate the dirtyness of glob's reflected gels or stacks 
								; to the glob itself!
								;-----------------
								propagate?: func [
									plug [object!]
								][
									vin ["!glob/reflection/[" plug/sid "]/propagate?()"]
									vprobe plug/valve/type
									plug/glob/valve/dirty plug/glob
									vout
									true
								]
								
								;-----------------
								;-        process()
								;-----------------
								process: func [
									plug
									data
								][
									plug/liquid: copy []
									vin ["!glob/reflection/[" plug/sid "]/process()"]
									forall data [
										append plug/liquid first data
									]
									vout
								]
							]
						]
					]
					glob/reflection/valve/unlink glob/reflection
					foreach layer layers [
						vprint ["linking to layer: " layer]
						either layer: pick glob/layers layer [
							glob/reflection/valve/link glob/reflection layer
						][
							vprint "This layer isn't set in glob"
						]
					]
				][
					; layers set to none, deconstruct reflection if one is currently set.
					
					; <TO DO>
				]
				vout
			]
			
			
			
			
			;--------------------
			;-    process()
			;--------------------
			process: func [
				""
				plug [object!]
				data [block!]
			][
				vin/tags ["!glob[" plug/sid "]/process()"] [process]
;				clear first plug/liquid
;				clear second plug/liquid
;				
;				append first  plug/liquid compose/deep bind/copy specs/1 'data
;				append second plug/liquid compose/deep bind/copy specs/2 'data
				
				;probe first plug/liquid
				;probe second plug/liquid
				;append/only plug/liquid head insert (copy/deep first plug/liquid) compose [pen (to-color plug/sid)]
				;plug/liquid: data
				if plug/reflection [
					plug/liquid: plug/reflection/valve/content plug/reflection
				]
				vout/tags [process]
			]
			
			
			;--------------------
			;-    pre-allocate-layers()
			; this creates a number of stack nodes ready for use.  so observers can be 
			; connected before the glob connects to other globs.
			;--------------------
			pre-allocate-layers: func [
				glob [object!]
				count [integer!]
				;/local stack
			][
				if none? glob/layers [
					glob/layers: copy []
				]
				loop count [
					append glob/layers  liquify !stack
				]
			]
			
			
			;--------------------
			;-    add-layers()
			;--------------------
			add-layers: func [
				""
				glob [object!]
				/local words spec paren ext val
			][
				vin/tags ["!glob[" glob/sid "]/add-layers()"] [add-layers]
				
				if gel-spec [
					parse gel-spec [
						some [
							;(words: copy [])
							copy val some word! (words: val if words/1 = 'none [words: none])
							|
							copy val paren! (ext: bind/copy to-block val/1 'process )
							|
							copy val block! (spec: val  add-layer/with glob  words spec/1 ext  ext: none)
						]
					]
				]
				vout/tags [add-layers]
			]
			
			;--------------------
			;-    add-layer()
			;--------------------
			add-layer: func [
				""
				glob [object!]
				words [block! none!]
				spec  [block!]
				/with extension
				/local gel word input
			][
				vin/tags ["!glob[" glob/sid "]/add-layer()"] [add-layer]
				vprint ["adding layer: " words]
				;probe extension
				;probe words
				extension: any [extension []]
				gel: liquify/with !gel extension
				
				gel/glob: glob
				
				;probe get in gel 'blocking-state
				
				append glob/layers gel
				;lqd/von
				; link appropriate layers to it
				if words [
					foreach word words [
						unless input: select glob/input word [
							to-error rejoin ["GLOB/add-layer(): glob has no input named '" word]
						]
						gel/valve/link/label gel input word
					]
				]
				
				;link our plug sid, this never changes, so don't make a plug for this
				gel/plug-sid: glob/sid
				
				;lqd/voff
				
				; share appropriate effects blk
				
				gel/draw-spec: spec
				
				
				vout/tags [add-layer]
			]
		

			;--------------------
			;-    add-inputs()
			;--------------------
			add-inputs: func [
				""
				glob
				/local  item type spec input default
			][
				vin/tags ["!glob[" glob/sid "]/add-inputs()"] [add-inputs]
				;probe glob/valve/input-spec
				if glob/valve/input-spec [
				
					; new flexible dialect
					until [
						;probe ">"
						; input spec is a value of the valve, so its bound to it
						item: pick glob/valve/input-spec 1
						switch type?/word item [
							word! [
								either  #"!" = first to-string item [
									type: item
									
									; reset default, to prevent data type errors
									; note: if you don't change types between inputs, all will 
									; use the same default (this is a feature)
									default: none
								][
									; add input if we have everything we need
									if all [input type][
										add-input/preset glob input type default
									]
									
									; name of following node
									input: item ; name of the input
									
									;---
									; note: even if the last thing of a input block is a word (and 
									; not allocated here, the end of the loop will create it)
								]
							]
;							block! [
;								probe item
;							]
							
							paren! [
								; parens allows the user to supply programmable default values
								;probe item
								default: do item
							]
						]
						
						glob/valve/input-spec: skip glob/valve/input-spec 1
						tail? glob/valve/input-spec 
					]
					glob/valve/input-spec: head glob/valve/input-spec
					; at the end of the loop, we generally have one input left to allocate... (unless missing data)
					if all [input type][
						add-input/preset glob input type default
					]
				]
				vout/tags [add-inputs]
			]
			
			;--------------------
			;-    add-input()
			;--------------------
			add-input: func [
				""
				glob [object!]
				name [word!]
				type [word!]
				/preset value "data you wish to fill the input with at allocation"
				/local plug
			][
				vin/tags ["!glob[" glob/sid "]/add-input()"] [add-input]
				; allocate new input
				;print ["new: " type " named: " name " filled with: " value]
				
				plug:  liquify intypes/:type
				
				; put the node in our store of inputs, for proper handling in other tasks
				append glob/input reduce [name plug]
				
				; listen to that input.
				; glob/valve/link/label glob plug name ; no more, the gels now listen directly.
				
				unless none? value [
					;probe value
					plug/valve/fill plug value
					;probe plug/valve/content plug
				]
				
				vout/tags [add-input]
			]
					
			;--------------------------------------------------------
			; the state managers are a test within the scope of liquid
			; these do not fill the data in the normal way, they actuall
			; modify the block in-place.
			; 
			; the state input is a simple container... not piped.
			;--------------------------------------------------------
			;--------------------
			;-    set-state()
			;--------------------
			set-state: func [
				""
				plug [object!]
				state [word!]
				;/local blk
			][
				vin/tags ["!glob[" plug/sid "]/set-state()"] [set-state]
				if plug: select plug/input state [
					; prevent state propagation, if state does not actually change
					;unless plug/liquid [
						fill plug true
					;]
				]
				vout/tags [set-state]
			]
			
			;--------------------
			;-    clear-state()
			;--------------------
			clear-state: func [
				""
				plug [object!]
				state [word!]
			][
				vin/tags ["!glob[" plug/sid "]/clear-state()"] [clear-state]
				if plug: select plug/input state [
					; prevent state propagation, if state does not actually change
					;if plug/liquid [
						fill plug false
					;]
				]
				vout/tags [clear-state]
			]
			
			;--------------------
			;-    setup()
			;--------------------
			setup: func [
				"allocate non recyclable glob data. scans the inputs block and allocates inputs based on that."
				glob [object!]
				/local  item type spec input default
			][	
				vin/tags ["!glob[" glob/valve/type":"glob/sid "]/setup()"] [setup]
				glob/input: copy []
				glob/layers: copy []
				add-inputs glob
				add-layers glob
				
				glob/valve/setup-glob-type glob ; 
				vout/tags [setup]
			]
			
			
			;--------------------
			;-    setup-glob-type()
			;--------------------
			setup-glob-type: func [
				"just a handy way to allow special glob inits after internal glob setup"
				glob [object!]
			][
				
			]
			
			
			;--------------------
			;-    destroy()
			;--------------------
			destroy: func [
				""
				glob [object!]
				/local item dummy
			][
				;von
				vin/tags ["!glob/destroy()"] [destroy]
				vprint "destroy glob-type stuff"
				glob/valve/destroy-glob-type glob
				
				vprint "destroy gels or layers"
				foreach item glob/layers [
					if item [
						item/valve/destroy item
					]
				]
				clear head glob/layers
				glob/layers: none
				
				vprint "destroy inputs"
				foreach [dummy item] glob/input [
					item/valve/destroy item
				]
				clear head glob/input
				glob/input: none
				
				
				!plug/valve/destroy glob
				
				if object? glob/reflection [
					glob/reflection/valve/destroy glob/reflection
				]
				
				glob/draw-spec: none
				
				vout/tags [destroy]
				;voff
			]
			
			;--------------------
			;-    destroy-glob-type()
			;--------------------
			destroy-glob-type: func [
				"Destroy what was created by setup-glob-type()"
				glob
			][
				vin/tags ["destroy-glob-type()"] [destroy-glob-type]
				
				vout/tags [destroy-glob-type]
			]
			
			;--------------------
			;-    link()
			;--------------------
			; note, current version of glob only supports (and expects) links to other globs
			link: func [
				observer [object!]
				subordinate [object!]
				/head "setting this refinement, tells the engine to put the link at the head of all subordinates"
				/reset "unlink and unpipe node prior to link"
				/local layer stack i
			][
				vin ["!glob/link()"]

				; first start by doing liquid link of globs themselves.
				any [
					all [reset head (!plug/valve/link/head/reset observer subordinate true)]
					all [reset (!plug/valve/link/reset observer subordinate true)]
					all [head (!plug/valve/link/head observer subordinate true)]
					!plug/valve/link observer subordinate
				]
				
				if none? observer/layers [
					observer/layers: copy []
				]
				
				; here we assume your are providing proper plugs. 
				; you can only link empty globs or stack globs. 
				; If you link (the observer is) a gel glob, you are effectively 
				; corrupting your display, or an error might be (eventually) raised.
				i: 0
				foreach layer subordinate/layers [
					; make sure we have enough layers.
					i: i + 1
					unless stack: pick observer/layers i [
						vprint "ADDING LAYER"
						append observer/layers stack: liquify !stack
					]
					;probe length? observer/layers
					
					; let the stack observe the layer.
					any [
						;all [reset head stack/valve/link/reset/head stack layer true]
						;all [reset stack/valve/link/reset stack layer true]
						all [head (stack/valve/link/head stack layer true)]
						stack/valve/link stack layer
					]
				]
				
				;probe length? subordinate/layers
				
				; then link a stack for each element in the subordinate
				;probe length? subordinate/layers
				vout
			]
				
			
			;--------------------
			;-    unlink()
			;--------------------
			unlink: func [
				""
				plug [object!]
				/only oplug [object!]  "only supports glob pointers."
				/local layer i
			][
				vin/tags ["!glob/unlink()"] [unlink]
				either only [
				;	print type? plug
					;print type? plug/layers
					;probe length? plug/layers
					
					if oplug/layers [
						if plug/layers [
							i: 0
							foreach layer plug/layers [
								i: i + 1
								
								if oplug/layers/:i [
									layer/valve/unlink/only layer oplug/layers/:i
								]
							]
						]
					]
					!plug/valve/unlink/only plug oplug
				][
					if plug/layers [
						foreach layer plug/layers [
							layer/valve/unlink layer
						]
					]
					!plug/valve/unlink plug
				]
				
				vout/tags [unlink]
			]
			
			
			;--------------------
			;-    cleanse()
			;--------------------
			cleanse: func [
				""
				plug [object!]
			][
				vin/tags ["!glob:" plug/valve/type"[" plug/sid "]/cleanse()"] [cleanse]
				plug/liquid: copy/deep []
				;plug/input/offset/valve/fill plug/input/offset 0x0
				vout/tags [cleanse]
			]

			;--------------------
			;-    feel[]
			;--------------------
			feel: context [
				;--------------------
				;-        on-key()
				;--------------------
				; triggered if focus is false or if it returns false and the mouse is over the item 
				;--------------------
				on-key: func [
					glob "the glob object itself"
					canvas "face this glob was viewed from (a glob can be used on several canvases)"
					event "original view event, note event/offset is window related"
					offset "offset relative to canvas"
				][
					; does this consume the event? (some keys could be considered control keys later on... needs more reflection)
					true
				]


				;--------------------
				;-        on-type()
				;--------------------
				; this is used when glob has focus
				;--------------------
				on-type: func [
					glob [object!]
					;canvas [object!]
					event
					;offset  [pair!]  "precalculated position removing any offset, origin"
				][
					
					; does this consume the event? (some keys could be considered control keys later on... needs more reflection)
					true
				]
				
				
				
				;-----------------
				;-        on-scroll()
				;-----------------
				on-scroll: func [
					glob "the glob object itself"
					canvas "face this glob was viewed from (a glob can be used on several canvases)"
					event "original view event, note event/offset is window related"
					offset "offset relative to canvas"
				][
					vin [{"" glob/valve/type "[" glob/sid "]/ON-SCROLL()}]
					vout
				]
				
				
				
				
	
				
				;--------------------
				;-        on-over()
				;--------------------
				; when the mouse goes from elsewhere TO this item
				;--------------------
				on-over: func [
					glob "the glob object itself"
					canvas "face this glob was viewed from (a glob can be used on several canvases)"
					event "original view event, note event/offset is window related"
					offset "offset relative to canvas"
				][
					vprint ["" glob/valve/type "[" glob/sid "]/ON-OVER()"]
					;false
					vout
				]
				
				
				;--------------------
				;-        on-top()
				;--------------------
				; when the mouse continues hovering over the item
				;--------------------
				on-top: func [
					glob "the glob object itself"
					canvas "face this glob was viewed from (a glob can be used on several canvases)"
					event "original view event, note event/offset is window related"
					offset "offset relative to canvas"
				][
					vprint ["" glob/valve/type "[" glob/sid "]/ON-TOP()"]
					;false
					vout
				]
				
				
				;--------------------
				;-        on-away()
				;--------------------
				; when the hover leaves the item
				; on-away() and on-over() are ALWAYS called in pair.
				;--------------------
				on-away: func [
					glob "the glob object itself"
					canvas "face this glob was viewed from (a glob can be used on several canvases)"
					event "original view event, note event/offset is window related"
					offset "offset relative to canvas"
				][
					vprint ["" glob/valve/type "[" glob/sid "]/ON-AWAY()"]
					;false
					vout
				]
				
				
				;--------------------
				;-        pick?()
				;--------------------
				; return true IF this item can be picked for drag and drop.
				; 
				; if so, drag events occur.
				; 
				; otherwise normal hover continues and on select is called instead
				;--------------------
				pick?: func [
					glob "the glob object itself"
					canvas "face this glob was viewed from (a glob can be used on several canvases)"
					event "original view event, note event/offset is window related"
					offset "offset relative to canvas"
				][
					false
				]
				


				;--------------------
				;-        on-select()
				;--------------------
				; only triggered when pick? isn't true
				;--------------------
				on-select: func [
					glob "the glob object itself"
					canvas "face this glob was viewed from (a glob can be used on several canvases)"
					event "original view event, note event/offset is window related"
					offset "offset relative to canvas"
				][
					vin/tags ["glob/valve/feel/on-select()"] [on-drag]
					
					vout/tags [on-drag]
				]
				

				;--------------------
				;-        on-release()
				; occurs when mouse was released but no drag occured
				;--------------------
				on-release: func [
					glob "the glob object itself"
					canvas "face this glob was viewed from (a glob can be used on several canvases)"
					event "original view event, note event/offset is window related"
					offset "offset relative to canvas"
				][
					vin/tags ["glob/valve/feel/on-select()"] [on-drag]
					
					vout/tags [on-drag]
				]
				
				
				;-----------------
				;-        on-pick()
				;-----------------
				; called when mouse is pressed over item and pick? returned true
				;-----------------
				on-pick: func [
					glob "the glob object itself"
					canvas "face this glob was viewed from (a glob can be used on several canvases)"
					event "original view event, note event/offset is window related"
					offset "offset relative to canvas"
				][
					vin [{glob/valve/feel/on-pick()}]
					vout
				]
				
				
				
				;--------------------
				;-        on-drag()
				;--------------------
				on-drag: func [
					glob "the glob object itself"
					canvas "face this glob was viewed from (a glob can be used on several canvases)"
					event "original view event, note event/offset is window related"
					offset "offset relative to canvas"
				][
					vin "glob/valve/feel/on-drag()"
					
					vout
					false
				]
				
				
				
				;--------------------
				;-        on-drop()
				;--------------------
				; only called when mouse is released and drag occured (complements on-pick)
				;--------------------
				on-drop: func [
					glob "the glob object itself"
					canvas "face this glob was viewed from (a glob can be used on several canvases)"
					event "original view event, note event/offset is window related"
					offset "offset relative to canvas"
				][
					vin [{glob/valve/feel/on-drop()}]
					vout
					false
				]
				
				
				
				;--------------------
				;-        on-down()
				;--------------------
				on-down: func [
					""
					gadget
					canvas
					event
				][
					false
				]


				;--------------------
				;-        on-up()
				; up is called everytime a mouse button is released, in all cases.
				;--------------------
				on-up: func [
					""
					gadget
					canvas
					event
				][
					false
				]


				;--------------------
				;-        on-alt-down()
				;--------------------
				on-alt-down: func [
					""
					gadget
					canvas
					event
				][
					false
				]


				;--------------------
				;-        on-alt-up()
				;--------------------
				on-alt-up: func [
					""
					gadget
					canvas
					event
				][
					false
				]



				
				
			]

		]
		
		

	]
	
	
	;-  
	;------------------------
	;;- !GLOB-EX
	;------------------------
	; quick example of a glob
	;------------------------
	!glob-ex: make !glob [
		valve: make valve [
			;-    input-spec:
			input-spec: [
				; list of inputs to generate automatically on setup  these will be stored within the instance under input
				start !pair (random 30x30)
				end !pair ((random 30x30) + 30x30)
				offset !pair
				color !color
				hi !state
			] 
			
			
			;-    gel-spec:
			gel-spec: [
				; mask
				start offset end 
				[line-width 3 pen (to-color gel/plug-sid) line (data/start= + data/offset=) (data/end= + data/offset=)]
				
				; line
				color start offset end hi
				[line-width 2 pen (either data/hi= [data/color= * 1.25 + 30.30.30][data/color=]) line (data/start= + data/offset=) (data/end= + data/offset=)]
				
				; dots
				color start offset end
				[line-width 2 pen (data/color=) circle (data/start= + data/offset=) 5  circle (data/end= + data/offset=) 5]
				
			]
		]
	]
	
	

	
	;-  
	;- !rasterizer:
	;
	;
	; inputs
	;     size:     size of output image
	;     offset:   offset to apply to draw block
	;     bg-color: the image is flushed with this color at each refresh.
	;     drawing:  an AGG draw block to rasterize
	;
	; optional inputs
	;     drawing:  any number of AGG draw blocks to rasterize
	;       ...
	;
	; notes:
	;     inputs MUST be of proper type.
	;     usually we connect the drawing to a layer of a glob directly.
	;
	!rasterizer: make !plug [
		; plug/liquid : image!
		
		;-     image:
		; we store the image to use so we can refer to it later and re-allocate it
		; when image size changes.
		image: none
		
		valve: make valve [
			;-----------------
			;-     process()
			;-----------------
			process: func [
				plug
				data
				/local img-size img-offset drawing drawings bg
			][
				vin [{!rasterizer/process()}]
				img-size: pick data 1
				img-offset: pick data 2
				bg: pick data 3
				
				; compose drawing
				drawings: at data 4
				drawing: clear []
				foreach item drawings [
					append drawing item
				]
				
				; create or reuse image
				plug/image: any [
					all [
						image? plug/image
						img-size = plug/image/size
						plug/image
					]
					make image! img-size
				]
				
				;print "================================================="
				;print "rasterizer/process()"
				;print type? plug/image
				;view/new layout [image plug/image]
				;print "================================================="
				
				; reset image background
				plug/image/rgb: bg
				plug/image/alpha: any [pick bg 4 0]
				
				; render image
				draw plug/image compose [translate (img-offset) (drawing)]
				
				
				; assign liquid
				plug/liquid: plug/image
				
				vout
			]
			
		
		]
	]
	
	
	
	;-  
	;-  !IMGSTORE
	; use this liquid to always have an up to date image representation of a !glob network.
	; nice thing is that you can link it at any stage and on any layer  :-)
	;
	; since it is on demand, causing massive amounts of change to stack, will not
	; bog down the imgstore, since it will basically do nothing, until the img really
	; is needed.
	!imgstore: make !plug [
		buffer: none
		draw-blk: none ; stores the draw effect we are rendering
		
		
		valve: make valve [
			type: '!imgstore
			
			;--------------------
			;-    setup()
			;--------------------
			setup: func [
				""
				plug [object!]
			][
				vin/tags ["!imgstore/setup()"] [setup]
				plug/buffer: make face copy/deep [
					size: 0x0
					edge: none
					color: white ; reaching white is almost impossible (16 million nodes) 
					feel: none
					font: none 
					text: none 
					effect: [draw []]
				]
				
				; preset our block... just for speed.
				plug/draw-blk: plug/buffer/effect/2
				append plug/draw-blk [anti-alias #[false]]
				vout/tags [setup]
			]
			
			;--------------------
			;-    cleanse()
			;--------------------
			cleanse: func [
				""
				plug [object!]
			][
				vin/tags ["!imgstore/cleanse()"] [cleanse]
				plug/liquid: make image! 10x10
				vout/tags [cleanse]
			]
			
			;--------------------
			;-    process()
			;--------------------
			process: func [
				""
				plug [object!]
				data [block!]
				/local img size blk
			][
				vin/tags ["!imgstore/process()"] [process]
				blk: plug/draw-blk
				
				; keep the anti-alias word
				clear at blk 3
				
				append blk reduce ['translate data/3]
				
				if all [
					pair? pick data 1  ; the size of the canvas 
				][
					foreach item next data [
						if block? item [
							append blk item
						]
					]
					plug/liquid: draw make image! reduce [first data white] blk
				]
				
				vout/tags [process]
				plug/liquid
			]
		]
	]
]



;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %glob.r 
    date: 2-Feb-2010 
    version: 1.0.0 
    slim-name: 'glob 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: GLOB
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: SILLICA  v0.1.2
;--------------------------------------------------------------------------------

append slim/linked-libs 'sillica
append/only slim/linked-libs [


;--------
;-   MODULE CODE



;- slim/register/header
slim/register/header [

	;- LIBS
	
	include: include-different: find-same: get-application-title: remove-duplicates: text-to-lines: 
	shorter?: longer?: shortest: longest: shorten: elongate: ydiff: xdiff: swap-values: none
	
	utils-lib: slim/open/expose 'utils none [
		include include-different find-same get-application-title remove-duplicates text-to-lines 
		shorter? longer? shortest longest shorten elongate ydiff xdiff swap-values
	]
	
	!glob: none
	glob-lib: slim/open/expose 'glob none [!glob]
	
	
	!plug: liquify*: content*: fill*: link*: unlink*: none
	liquid-lib: slim/open/expose 'liquid none [!plug [liquify* liquify ] [content* content] [fill* fill] [link* link] [unlink* unlink]]

	; bulk is the only library which shares functions directly in the global space.  
	; reason is historical.  Namespace clash is prohibitively low since all bulk funcs have "bulk" in their names.
	slim/open 'bulk none

	;- WORD ALIASES
	;-     max*  min*
	max*: :max
	min*: :min
	

	

	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;
	;-    master-stylesheet:
	; the default master marble stylesheet
	; stored as pairs of style names and reference marble objects
	master-stylesheet: []
	
	
	;-    rebol-version:
	rebol-version: system/version/1 * 10000 + ( system/version/2 * 100) + system/version/3
	
	
	;-    debug-mode?:
	;
	; this is a level based setup.
	;
	; 0= no debug
	; 1= a few print outs, like the refresh "." check
	; 2= debug printouts
	; 3= heavy and application slowing debug, ex: AGG block saved to disk.
	debug-mode?: 0
	
	;-    glass-debug-dir:
	set 'glass-debug-dir join what-dir %debug/
	

	;- THEME
	;base-font: make face/font [style: none size: 13 name: "Trebuchet MS"]
	;base-font: make face/font [style: none size: 13 name: "Arial"]
	;base-font: make face/font [style: none size: 13 name: "Tahoma"]
	
	;-        -fonts
	base-font: make face/font [name: "verdana" size: 13 style: none bold?: false]
	mono-font: make face/font [name: font-fixed bold?: false char-width: 7]
	
	set 'theme-base-font base-font 
	
	set 'theme-knob-font make base-font [size: 13 bold?: true]
	set 'theme-small-knob-font make base-font [size: 11 bold?: none]
	set 'theme-menu-item-font make base-font [size: 11 bold?: none]
	set 'theme-list-font make base-font [size: 11]
	
	set 'theme-field-font make mono-font [size: 12]
	set 'theme-editor-font make mono-font [size: 12]
	
	set 'theme-label-font make base-font [size: 11  ] ;aliased?: true]
	set 'theme-headline-font make base-font [size: 13  bold?: true]
	set 'theme-title-font make base-font [size: 20]
	set 'theme-subtitle-font make base-font [size: 14 bold?: true]
	set 'theme-requestor-title-font make base-font [size: 14 bold?: true]
	set 'theme-editor-char-width 7
	set 'theme-field-char-width 7
			
	
	;-        -colors
	; these are set globally
	set 'theme-color blue
	set 'shadow 0.0.0.128
	set 'light-shadow 0.0.0.200
	set 'theme-bg-color white * .85
	set 'theme-recess-color white * .6
	set 'theme-window-color theme-bg-color
	set 'theme-border-color white * .4
	set 'theme-knob-border-color white * .3
	set 'theme-knob-color white * .9
	set 'theme-glass-color theme-color
	set 'theme-glass-transparency 175
	set 'theme-bevel-color white * .85
	set 'theme-requestor-bg-color white * .89
	set 'theme-progress-bg-color white
	


	empty-face: make face [
		size: 0x0
		font: none
		edge: none
		;para: none
		effect: none
		text: none
		offset: 0x0
		feel: none
		pane: none
		
	]
	

	;-    text-sizer:
	text-sizer: make empty-face [
		size: 200x200
		para: make para [wrap?: false]
		font: base-font
	]
	
	
	;-    label-text-sizer:
	; this is used exclusively by the label-dimension function
	label-text-sizer: make face [
		size: 200x200 
		para: make para [wrap?: false]
		edge:  none
		font: base-font
		para: make para []
		para/origin: 0x0
		para/margin: 0x0


	]
	


	
	;--------------------------------------------------------
	;-   
	;- PARSE RULES
	;
	non-space: complement charset " "
	
	set '**letter charset [#"a" - #"z" #"A" - #"Z"]
	set '**whitespace charset "^- ^/"
	
	
	;--------------------------------------------------------
	;-   
	;- UTILITY FUNCTIONS
	;

	
	;--------------------------------------------------------
	;-   
	;- GRAPHIC PRIMITIVE FUNCTIONS
	;
	;

	;-----------------
	;-    label-dimension()
	;-----------------
	label-dimension: func [
		text
		font
		/width w
		/height h
		/wrap? ww
		;/align a
		/local size b
	][
		
		label-text-sizer/size: 10000x10000
		if wrap? [
			label-text-sizer/size/x: ww
		]
		
		label-text-sizer/para/wrap?: wrap?
		label-text-sizer/font: font
		
		label-text-sizer/text: text
		
		;label-text-sizer/font/align: any [a 'left] ; should not really make any difference
		;label-text-sizer/font/offset: 0x0
		case [
			width [
				label-text-sizer/size/x: w
				size: size-text label-text-sizer
				size/x: w
				size
			]
			height [
				label-text-sizer/size/y: h
				size: size-text label-text-sizer
				size/y: h
				size
			]
			true [
				size-text label-text-sizer
			]
		]
	]
	
	
	
	;-----------------
	;-    top-half()
	;-----------------
	top-half: func [
		position
		dimension
		/absolute "dimension is an absolute value, calculate its delta"
	][
		if absolute [dimension: dimension - position - 1x1]
		reduce [position (position + (1x0 * dimension) + (0x1 * dimension / 2) )]
	]
	
	;-----------------
	;-    bottom-half()
	;-----------------
	bottom-half: func [
		position
		dimension
	][
		reduce [( 0x1 * dimension / 2 + position) (position + dimension - 1x1)]
	]
	
	
	
	;-----------------
	;-    clip-strings()
	;
	; more effective to call this with a block of strings, even if there is only one.
	;
	; return value is always a block whatever the input was.
	;
	; note: we trim spaces at tail to make sure offset-to-caret returns proper values... its buggy... 
	;-----------------
	clip-strings: func [
		strings [string! block!]
		width [integer! pair!]
		font
		/local item item-end align?
	][
		vin [{clip-strings()}]
		
		align?: font/align
		
		; make sure box fits some text
		width: 1x0 * width +  -1x5
		text-sizer/size: 1000x100
		text-sizer/para/wrap?: false
		text-sizer/font: font
		
		text-sizer/font/align: 'left
		text-sizer/edge:  none
		text-sizer/font/offset: 0x0
		text-sizer/para/origin: 0x0
		text-sizer/para/margin: 0x0
		
		unless block? strings [
			strings: compose [(string)]
		]
		
		unless empty? strings [
			until [
				item-end: ""
				item: trim/tail first strings
				text-sizer/text: item
				item-end: offset-to-caret text-sizer width
				; make space for arrow
				either empty? item-end [
					item-end: none
				][
					item-end: -1 + index? item-end 
				]
				strings: change/part strings reduce [item  item-end] 1
				
				tail? strings
			]
		]
		; restore original text alignment.
		font/align: align?
		vout
		strings
	]
	
	
	

	;-----------------
	;-    prim-bevel()
	;-----------------
	prim-bevel: func [
		position
		size
		color
		contrast
		width
		/invert
		/local start end
	][
		vin [{prim-bevel()}]
		vout
		size: size - 1x1
		
		either invert [
			;print "bevel"
			compose [
				line-cap round
				line-width (width)
				pen (color - (white * contrast))
				line (position + (0x1 * size)) (position) (position + (1x0 * size))
				pen (color + (white * contrast))
				line (position + (0x1 * size)) (position + size) (position + (1x0 * size))
				
				line-width 1
				pen black
				box (position + (width / 2) ) (position + size - (0.5 * width ))
			]
		][
			compose [
			
				fill-pen none
				line-cap round
				line-width (width)
				
				pen (color - (white * contrast))
				line (position + ( size * 0x1) + (width / 2 * 1x-1)) (position + size - (width / 2)) (position + (1x0 * size)  + ( width / 2 * -1x1))
				
				pen (color + (white * contrast))
				line (position + ( size * 0x1) + (width / 2 * 1x-1)) (position  + (width / 2)) (position + (1x0 * size) + ( width / 2 * -1x1))
				
			]
		]
	]
	
	
	;-----------------
	;-    prim-X()
	;-----------------
	prim-X: func [
		position
		size
		color
		width
		/local colors
	][
		vin [{prim-x()}]
		vout
		size: size - 1x1
		compose [
			line-width (width)
			pen (color)
			line (position + (0x1 * size)) (position + (1x0 * size))
			line (position ) (position + size) 
		]
	]
	
	;-----------------
	;-    prim-label()
	;-----------------
	prim-label: func [
		text [string!]
		position [pair!]
		size [pair!]
		color [tuple!]
		font [object! none! integer!]
		align [word! none!] "Polar coordinates (N NE E SE S SW W NW) or 'center"
		/aliased "switches to aliased text carefull... doesn't respond to transform matrix"
		/pad p [integer! pair!] "If some of the align values are on the edges, this will push the text opposite to that edge"
		/local text-size offset font-size
	][
		vin [{prim-label()}]
		
		p: any [p 0x0]

		if integer? font [
			font-size: font
			font: none
		]
		font: any [font theme-base-font]
		
		
		if all [
			integer? font-size
			font-size <> font/size 
		][
			font: make font [size: font-size]
		]
		;font/valign: 'top
		;font/offset: 0x0
		
		;probe "--------------------------"
		;?? size
		
		text-size: label-dimension text font
		
		;?? text-size
		offset: switch/default align [
			W WEST left [
				p: p * 1x0
				position + (1x0 * p/x) + (size - text-size / 2 * 0x1) + 0x-2 + p
			]
			E EAST right [
				p: p * 1x0
				position - (1x0 * p/x) + (size - text-size * 1x0 ) + (size - text-size / 2 * 0x1) - 0x2 - p
			]
			S SOUTH bottom [
				p: p * 0x1
				(size - text-size / 2 * 1x0) + (size - text-size * 0x1) + position - 0x2 - p;+ (p/x * 1x0)
			
			]
		][
			; default is center
			size - text-size / 2 + position  ;+ (p/x * 1x0)
		]
		
			
		render-mode: any [
			all [aliased 'aliased] 
			all [
				in font 'aliased?
				font/aliased?
				'aliased
			]
			'vectorial
		]
		
		vout
		compose [
			font (font)
			(either render-mode = 'aliased [
				compose [pen (color)]
			][[]]
			)
			;fill-pen 200.0.0.200
			;box (position) (size + position)
			(
				either font/bold? [
					compose [line-width 0.3 pen (color)]
				][[]]
			)
			fill-pen (color )
			text (text) (offset) (render-mode)
			; workaround: fix a bug in AGG where vectorial text break alpha of following element.
			line 0x0 0x0
		]
	]
	
	
	
	;-----------------
	;-    prim-glass()
	;-----------------
	prim-glass: func [
		from "box start" [pair!]
		to "box end"  [pair!]
		color [tuple!]
		transparency [integer!] "0-255"
		/corners corner
		/only
		/no-shine
		/local height tmp border-clr
	][
		transparency: 0.0.0.255 * ( transparency / 255 )
		
		
		tmp: min from to
		to: max from to
		from: tmp
		
		border-clr: unless only [
			(black + transparency)
		]
		;corner: any [corner 0] ; HANGS AGG (probably trying to create an arc of radius 0  :-)
		;border-clr: none
		;print "!!!"
		compose [
			; glass color
			line-width 1
			fill-pen linear (from) 1 (height: second (to - from)) 90 1 1 ( color * 0.8 + (white * 0.2) + transparency ) ( color + transparency ) (color * 0.8 + transparency)
			pen (border-clr)
			box  ( from ) ( to ) corner
			
			
			; shine
			(either no-shine [				
				compose [
					pen none
					fill-pen (255.255.255.225)
					box ( top-half/absolute  from  to  ) corner
				]
			][
				compose [
					pen none
					fill-pen (255.255.255.175)
					box ( top-half/absolute  from  to  ) corner
				]
			])
			
			
			; shadow
			fill-pen linear (from: from * 1x0 + (to - 0x5 * 0x1)) 1 5 90 1 1 
				0.0.0.255
				0.0.0.225
				0.0.0.180
			box ( from ) ( to ) corner
			
			pen border-clr ;(black + transparency)
			line (from * 1x0 + (to * 0x1)) (to )
			
		]
	]
	
	
	;-----------------
	;-    prim-text-area()
	;-----------------
	prim-text-area: func [
		position [pair!]
		size [pair!] "Items will be shown until dimension height is hit"
		lines [block!] "A one column bulk. "
		font [object!] "A properly setup font which has a char-width attribute."
		leading [integer!]  "Added distance between lines."
		left [integer!] "First visible character to the left of view."
		top [integer!]  "First line to display, regardless of columns in list."
		cursors [block! none!] "A block of pairs which is used to display cursors"
		selections [block! none!] "A block of pairs which is used to display selections areas relative to the cursors"
		crs-clr [tuple!] "Color of cursors."
		text-color [tuple!] "Color of text."
		selection-color [tuple!]
		/cursor-lines cline-clr [tuple!]"If used, will add a colored line behind the cursors."
		
		/local  blk char-width colored-lines font-box chars line-count cursor-offset clines pos cpos
				l line-height line selection
		
	][
		vin [{prim-text-area()}]
		blk: clear []            ; saves on memory recycling
		
		
		; font MUST be setup properly (no fallback)
		either char-width: get in font 'char-width [
			lines: next lines											; skip bulk header
			colored-lines: clear []                                     ; accumulate lines we've already colored, so we don't overlap several draw boxes for nothing.
			font-box: (char-width * 1x0 + (font/size + leading * 0x1))  ; size of a single char
			chars: to-integer size/x / char-width                       ; max width of view in characters
			line-count: to-integer size/y / font-box/y                  ; max number of lines in display
			cursor-offset: (left * -1x0 + ( top * 0x-1)) * font-box     ; offset (in pixels) of cursor drawing, based on text scrolling
			
			
			if cursors [
				clines: clear []
				foreach cursor cursors [
					; make sure cursor is visible
					unless any [
						cursor/y < top
						cursor/y > (top + line-count)
					][
						pos: cursor * font-box + position + cursor-offset
						
						; add line bg color?
						if cline-clr [
							unless find colored-lines cursor/y [
								append blk compose [
									fill-pen (cline-clr) 
									pen none 
									box (  cpos: ( (pos * 0x1 ) + (position * 1x0) ) )   (cpos + (size  * 1x0) + (font-box * 0x1))
								]
								append colored-lines cursor/y
							]
						]
							
						; add cursors
						unless any [
							cursor/x < left
							cursor/x > (left + chars)
						][
							append blk compose [
								line-width 3 pen (crs-clr) fill-pen none
								line (pos) (pos + (font-box * 0x1))
							]
						]
					]
				]
			]
			
			
			
			;--------------------------------
			; draw selections
			;--------------------------------
			append blk compose [pen none fill-pen (selection-color)]
			until [
				if selection: pick selections 1 [
					
					if all [
						cursor: pick cursors index? selections
						cursor <> selection 
					][
					
						if any [
							cursor/y < selection/y
							all [cursor/y = selection/y cursor/x < selection/x]
						][
							swap-values cursor selection
						]
						
						until [	
							if all[
								line: pick lines selection/y 
								top <= selection/y
								top + line-count >= selection/y
							][
								; calculate box of current line to highlight
									selection/x: max selection/x left
								either cursor/y = selection/y [
									cpos: (cursor/x - selection/x - 1)
									if cpos >= 0 [
										pos: (selection * font-box) + cursor-offset + position
										cpos: pos + (cpos * font-box * 1x0) + font-box
										append blk reduce ['box pos cpos]
									]
								][
									if 0 <= cpos: (length? line) - selection/x [
										pos: (selection * font-box) + cursor-offset + position
										cpos: pos + ( cpos * font-box * 1x0) + font-box
										append blk reduce ['box pos cpos]
									]
								]
							]
							selection: selection + 0x1
							selection/x: 1
							selection/y > cursor/y
						]
					]
				]
				tail? selections: next selections
			]
			
			
			
			;--------------------------------
			; draw text
			;
			; we now optimise the string handling so it copies as little strings as it must
			;--------------------------------
			l: 1                                 ; line count
			pos: leading * 0x1 + position - 0x2  ; position accumulator
			line-height: (0x1 * font-box)        ; prepared line position incrementor
			lines: at lines top
			
			append blk compose [font (font) line-width 1 pen (text-color)]

			until [
				line: first lines  ; get current line
				line: any [
					all [
						left + (length? line) < chars
						at line left
					]
					copy/part at line left chars
				]
				
				append blk compose [text ( pos) (line) aliased]
				pos: pos + line-height
				any [
					tail? lines: next lines
					(l: l + 1) > line-count
				]
			]
			
		][
			print "Error: given font doesn't have char-width property and is incompatible with prim-text-area()"
		]
		vout
		
		; uncomment for debugging
		;append blk compose [pen green box (position) (position + size  - 1x1)]
		
		;?? blk
		blk
	]
	
	
	
	
	
	;-----------------
	;-    prim-list()
	;
	; given a bulk, construct n draw block which represents it, clipped to a specifed area.
	;-----------------
	prim-list: func [
		position [pair!]
		dimension [pair!] ; items will be shown until dimension height is hit
		font [object!]
		leading [integer!] "added distance between lines"
		items [block!] ; a bulk. will use label-column, if specified in its properties or column one by default, otherwise.
		start [integer!] ; first line to display, regardless of columns in list
		chosen [block! none!]
		pen [tuple! none!]
		fill-pen [tuple! none!]
		/arrows "add arrows to indicate the text goes out of bounds of list"
		/local end blk label payload columns line-height i pos length arrow-offset list text highlight-start
		       label-column spaces
	][
		vin [{prim-list()}]
		
		columns: 2 ; this might be programable at some point.
		blk: head clear head [] ; we reuse the same block at each eval.
		end: position + dimension
		
		; rebol's left to right math makes the following seem wrong but proper result occurs.
		columns: get-bulk-property items 'columns
		column: any [
			get-bulk-property items 'label-column 
			1
		]
		items: extract at next items column columns
		items: at items start
		;data-list: at data-lit start - 1 * columns + 1
		
		; manage font-related stuff
		text-sizer/font: any [font base-font]
		line-height: font/size + leading * 0x1
		
		chosen: any [chosen []]
		
		
		; accumulate list to draw, 
		clip-strings list: items  dimension  font
		

		
		unless empty? list [
			insert tail blk reduce ['font font 'line-width 0 pen (pen) fill-pen (fill-pen)]
			until [
				label: first list
				length: second list
				text: either length [
					either arrows [
						text: copy/part label (length - 1)
					][
						text: copy/part label (length )
					]
				][label]
				;insert tail blk [box -1x-1 -1x-1]
				; convert leading spaces to pos offset (cures a BAD rendering bug with text)
				spaces: 0
				parse/all label [any [#" " (spaces: spaces + 1) | thru end]]
				;?? spaces
				
				insert tail blk 'text
				insert tail blk position + (leading / 2 * 0x1 + 2x-1) + (spaces  * font/size / 2 * 1x0)
				insert tail blk trim/head copy text
				insert tail blk 'vectorial
				
				if all [length arrows][
					insert tail blk compose [pen 0.0.0.200 fill-pen 0.0.0.200 ]
					text-sizer/text: text
					arrow-offset: size-text text-sizer 
					insert tail blk prim-arrow (arrow-offset/x * 1x0 + position + (line-height / 2) + 3x1 ) 7x7 'bullet 'right
					insert tail blk compose [pen (pen) fill-pen (fill-pen) ]
				]
				
				either find-same chosen label [
					unless highlight-start [
						highlight-start: position - 1x0
					]
				][
					if highlight-start [
						; add a glass effect to selection, spans multiple items!
						insert tail blk prim-glass highlight-start  (position + (dimension/x * 1x0) + 1x1) theme-glass-color theme-glass-transparency
						insert tail blk compose [pen (pen) fill-pen (fill-pen) ]
					]
					highlight-start: none
				]
				
				; increments
				position: position + line-height
				if position/y + line-height/y > end/y [
					list: tail list
				]
				
				; end condition
				tail? list: next next list
			]
			
			; make sure we add tail of selection if it goes past visible list.
			if highlight-start [
				; add a glass effect to selection, spans multiple items!
				insert tail blk prim-glass highlight-start  (position + (dimension/x * 1x0) + 1x1) theme-glass-color theme-glass-transparency
				insert tail blk compose [pen (pen) fill-pen (fill-pen) ]
			]
			
		]
		vout
		blk
	]
	
	
	;-----------------
	;-    prim-item-stack()
	;
	; returns a block: [ size [AGG block]]
	;-----------------
	prim-item-stack: func [
		p [pair!] "position"
		items [block!] ; flat block of label/value pairs.
		columns [integer!] ; 2 by default
		font [object!]
		leading [integer!]
		orientation [word!]
		/local line-size blk size
	][
		vin [{prim-item-stack()}]
		line-size: font/size + leading * 0x1
		text-sizer/font: font


		blk: compose [
			
			font (font)
		]
		items: extract items columns

		size: 0x0

		foreach item items [
			append blk compose [
				text (p) (item) vectorial
			]
			p: p + line-size
			text-sizer/text: item
			size: p + second size-text text-sizer
		]
			
		vout
		reduce [size blk]
	]
	
	
	
	
	;-----------------
	;-    prim-arrow()
	;
	; notes:
	;    -dimension will affect scale and length depending on types.
	;     usually the perpendicular length is scale
	;    -orientation doesn't rotate dimension.
	;    -position is tip of arrow
	;    -for best results dimension should be an odd number
	;    -no color or vector parameter is supplied here, set that up before calling the primitive.
	;-----------------
	prim-arrow: func [
		position [pair!]
		dimension [pair!] "x: length of shaft, if any.  y: scale" ; when x = y, arrowhead is equilateral.
		type [word!] "one of: opened closed bullet broad"
		orientation [word!] "one of:  up down left right"
		/local top bottom size blk
	][
		vin [{prim-arrow()}]
		; arrow tip is at 0x0
		top: (dimension/y / 2) * 0x-1  +  ( dimension/x * 0.7 * -1x0 ) 
		bottom: (dimension/y / 2) * 0x1 + ( dimension/x * 0.7 * -1x0 )
		
		;?? position
		;?? top
		;?? bottom
		
		blk: switch type [
			; -->
			shaft [
				
			]
			
			; --|>
			closed
			[
				
			]
			
			; |>
			bullet [
				switch orientation  [
					right [
						compose/deep [
							push [
								translate (position)
								polygon (0x0) (top) (bottom)
							]
						]
					]
					down [
						
						compose/deep [
							push [
								translate (position)
								rotate 90
								polygon (0x0) (top) (bottom)
							]
						]
					]
				]
			]
			
			; >
			broad [
			
			]
			
		]
		v?? blk
		vout
		blk
	]
	
	
	
	;-----------------
	;-    prim-knob()
	;-----------------
	prim-knob: func [
		position [pair!]
		dimension [pair!] ; does NOT do - 1x1 automatically
		color [tuple! none!]
		border-color [tuple! none!]
		orientation [word!] ; 'vertical | 'horizontal
		shadow [integer! none!]
		corner [integer!]
		/highlight "Use default highlight method"
		/grit "add a little bit of texture at the center of knob (follows orientation)"
		/local blk e pos width
	][
		vin [{prim-knob()}]

		color: any [color theme-knob-color]
		;color: red
		;border-color: any [border-color theme-knob-border-color]
		
		shadow: any [shadow 0]
		if shadow <> 0 [
			shadow: shadow + 1
		]
		
		;?? shadow
		
		; bug in draw...
		
		
		
		blk: compose either orientation = 'vertical [
			[
				(
					either 0 = shadow [[]][
						compose [
							; shadow
							pen none
							fill-pen linear ( e: (position + (dimension * 0x1) + 1x1)) 1 (4) 90 1 1 
								(0.0.0.180) 
								(0.0.0.240) 
								(0.0.0.255 )
							box (e + -1x-6) (e + (dimension * 1x0) + 0x3) (corner)
						]
					]
				)

				(
					; bug in AGG, when pen is none or color, objects have a different overall size by 1x1
					if border-color = none [
						dimension: dimension + 1x1
					]
					[]
				)

				; bg
				line-width 1
				pen (border-color)
				;fill-pen linear (position) 1 (dimension/x) 0 1 1 ( color * 0.8 + (white * .2)) ( color ) (color * 0.9 )
				fill-pen ( color * 0.8 + (white * .2))
				box (position) (position + dimension) (corner - 1)
				
				; shine
				fill-pen 255.255.255.170
				pen none
				box (position + 1x1) (position + (dimension * 1x0 / 2) + (dimension * 0x1)  ) (corner)
				
				
				(
					either grit [
						pos: position + (dimension / 2 * 0x1) + 3x0
						width: dimension * 1x0 - 6x0
						compose [
							line-width 1
							pen 0.0.0.200
							line (pos) (pos + width)
							line (pos + 0x3) (pos + width + 0x3)
							line (pos - 0x3) (pos + width - 0x3)
							pen 255.255.255.50
							line (pos + 0x1) (pos + width + 0x1)
							line (pos + 0x4) (pos + width + 0x4)
							line (pos - 0x2) (pos + width - 0x2)
						]
					][[]]
				)
				
			]
		][
			[
				(
					either 0 = shadow [[]][
						compose [
							; shadow
							pen none
							fill-pen linear ( e: (position + (dimension * 0x1) + 1x1)) 1 (4) 90 1 1 
								(0.0.0.200) 
								(0.0.0.240) 
								(0.0.0.255 )
							box (e + -1x-6) (e + (dimension * 1x0) + 0x1) (corner)
						]
					]
				)

				(
					; bug in AGG, when pen is none or color, objects have a different overall size by 1x1
					if border-color = none [
						dimension: dimension + 1x1
					]
					[]
				)

				; bg
				line-width 0
				pen (border-color)
				fill-pen linear (position) 1 (dimension/y) 90 1 1 ( color * 0.8 + (white * .2)) ( color ) (color * 0.9 )
				;fill-pen ( color * 0.8 + (white * .2))
				box (position) (position + dimension) (corner - 1)
				
				; shine
				fill-pen 255.255.255.170
				pen none
				box (position + 1x1) (position + (dimension * 0x1 / 2) + (dimension * 1x0)  ) (corner)
				
				
				(
					either grit [
						pos: position + (dimension / 2 * 1x0) + 0x3
						width: dimension * 0x1 - 0x6
						compose [
							line-width 1
							pen 0.0.0.200
							line (pos) (pos + width)
							line (pos + 3x0) (pos + width + 3x0)
							line (pos - 3x0) (pos + width - 3x0)
							pen 255.255.255.50
							line (pos + 1x0) (pos + width + 1x0)
							line (pos + 4x0) (pos + width + 4x0)
							line (pos - 2x0) (pos + width - 2x0)
						]
					][[]]
				)
				
			]
		]
		
		
		vout
		
		; we just this word to save some word binding.
		blk
	]



	if rebol-version < 20708 [
		; makes prim-knob safer with older versions of rebol which have troubles with too many gradients and texts
		;-----------------
		;-    prim-knob() v 2.7.6
		;-----------------
		prim-knob: func [
			position [pair!]
			dimension [pair!] ; does NOT do - 1x1 automatically
			color [tuple! none!]
			border-color [tuple! none!]
			orientation [word!] ; 'vertical | 'horizontal
			shadow [integer! none!]
			corner [integer!]
			/highlight "Use default highlight method"
			/grit "add a little bit of texture at the center of knob (follows orientation)"
			/local blk e pos width
		][
			vin [{prim-knob()}]
	
			color: any [color theme-knob-color]
			;color: red
			;border-color: any [border-color theme-knob-border-color]
			
			shadow: any [shadow 0]
			if shadow <> 0 [
				shadow: shadow + 1
			]
			
			;?? shadow
			
			; bug in draw...
			
			
			
			blk: compose either orientation = 'vertical [
				[
	;				(
	;					either 0 = shadow [[]][
	;						compose [
	;							; shadow
	;							pen none
	;							fill-pen linear ( e: (position + (dimension * 0x1) + 1x1)) 1 (4) 90 1 1 
	;								(0.0.0.180) 
	;								(0.0.0.240) 
	;								(0.0.0.255 )
	;							box (e + -1x-6) (e + (dimension * 1x0) + 0x3) (corner)
	;						]
	;					]
	;				)
	
					(
						; bug in AGG, when pen is none or color, objects have a different overall size by 1x1
						if border-color = none [
							dimension: dimension + 1x1
						]
						[]
					)
	
					; bg
					line-width 1
					pen (border-color)
					;fill-pen linear (position) 1 (dimension/x) 0 1 1 ( color * 0.8 + (white * .2)) ( color ) (color * 0.9 )
					fill-pen ( color * 0.8 + (white * .2))
					box (position) (position + dimension) (corner - 1)
					
					; shine
					fill-pen 255.255.255.170
					pen none
					box (position + 1x1) (position + (dimension * 1x0 / 2) + (dimension * 0x1)  ) (corner)
					
					
					(
						either grit [
							pos: position + (dimension / 2 * 0x1) + 3x0
							width: dimension * 1x0 - 6x0
							compose [
								line-width 1
								pen 0.0.0.200
								line (pos) (pos + width)
								line (pos + 0x3) (pos + width + 0x3)
								line (pos - 0x3) (pos + width - 0x3)
								pen 255.255.255.50
								line (pos + 0x1) (pos + width + 0x1)
								line (pos + 0x4) (pos + width + 0x4)
								line (pos - 0x2) (pos + width - 0x2)
							]
						][[]]
					)
					
				]
			][
				[
	;				(
	;					either 0 = shadow [[]][
	;						compose [
	;							; shadow
	;							pen none
	;							fill-pen linear ( e: (position + (dimension * 0x1) + 1x1)) 1 (4) 90 1 1 
	;								(0.0.0.180) 
	;								(0.0.0.240) 
	;								(0.0.0.255 )
	;							box (e + -1x-6) (e + (dimension * 1x0) + 0x3) (corner)
	;						]
	;					]
	;				)
	
					(
						; bug in AGG, when pen is none or color, objects have a different overall size by 1x1
						if border-color = none [
							dimension: dimension + 1x1
						]
						[]
					)
	
					; bg
					line-width 0
					pen (border-color)
					;fill-pen linear (position) 1 (dimension/y) 90 1 1 ( color * 0.8 + (white * .2)) ( color ) (color * 0.9 )
					fill-pen ( color * 0.8 + (white * .2))
					box (position) (position + dimension) (corner - 1)
					
					; shine
					fill-pen 255.255.255.170
					pen none
					box (position + 1x1) (position + (dimension * 0x1 / 2) + (dimension * 1x0)  ) (corner)
					
					
					(
						either grit [
							pos: position + (dimension / 2 * 1x0) + 0x3
							width: dimension * 0x1 - 0x6
							compose [
								line-width 1
								pen 0.0.0.200
								line (pos) (pos + width)
								line (pos + 3x0) (pos + width + 3x0)
								line (pos - 3x0) (pos + width - 3x0)
								pen 255.255.255.50
								line (pos + 1x0) (pos + width + 1x0)
								line (pos + 4x0) (pos + width + 4x0)
								line (pos - 2x0) (pos + width - 2x0)
							]
						][[]]
					)
					
				]
			]
			
			
			vout
			
			; we just this word to save some word binding.
			blk
		]	
	]
	
	





	
	;-----------------
	;-    prim-recess()
	;
	; a depression from bg using a slight gradient fill
	;-----------------
	prim-recess: func [
		position [pair!]
		dimension [pair!] ; does NOT do - 1x1 automatically
		color [tuple! none!]
		border-color [tuple! none!]
		orientation [word!] ; 'vertical | 'horizontal
		/highlight "Use default highlight method"
		/local blk
	][
		vin [{prim-recess()}]

		color: any [color theme-recess-color]
		;border-color: any [border-color theme-edge-color]
		
		blk: compose either orientation = 'vertical [
			[
				line-width 1
				pen border-color
				fill-pen linear (position) 1 (dimension/x) 0 1 1  (color * 0.8 ) ( color ) ( color * 0.8 + (white * .2))
				box (position) (position + dimension) 3
				
;				fill-pen 255.255.255.150
;				pen none
;				box (position + 1x1) (position + (dimension * 1x0 / 2) + (dimension * 0x1) ) 3
			]
		][
		
			[
				line-width 1
				pen border-color
				fill-pen linear (position) 1 (dimension/y) 90 1 1  (color * 0.8 ) ( color ) ( color * 0.8 + (white * .2))
				box (position) (position + dimension) 3
			]
		]
		
		
		vout
		
		; we just this word to save some word binding.
		blk
	]
	
	
	;-----------------
	;-    prim-cavity()
	;
	; a depression from bg using a slight gradient fill
	;-----------------
	prim-cavity: func [
		p [pair!] "position"
		d [pair!] "dimension" ; does NOT do - 1x1 automatically
		/colors 
			bg  [tuple! none!]
			border [tuple! none!]
		/all "put shadows on all four edges"
		/local blk
	][
		vin [{prim-cavity()}]
		
		blk: compose [
				; bg
				line-width 0
				fill-pen (bg)
				pen none
				box (p ) (p + d ) 3
		
				; top shadows
				pen none
				fill-pen linear (p + 1x1) 1 (5) 90 1 1 
					(0.0.0.200) 
					(0.0.0.235) 
					(0.0.0.255 )

				box (p + 1x1) (p + (d/x * 1x0) + 0x20) 3

				; left shadows
				fill-pen linear (p + 1x1) 1 (4) 0 1 1 
					(0.0.0.210) 
					(0.0.0.240) 
					(0.0.0.255 )
				box (p + 1x1) (p + (d/y * 0x1) + 4x0) 3
				
				(  either all [
						compose [
							; right shadows
							fill-pen linear (p + d) 1 (4) 180 1 1 
								(0.0.0.210) 
								(0.0.0.240) 
								(0.0.0.255 )
							box (d * 1x0 + p ) (p + d - 4x0) 3
							
							; bottom shadows
							fill-pen linear (p + (d )) 1 (4) 270 1 1 
								(0.0.0.210) 
								(0.0.0.240) 
								(0.0.0.255 )
							;box ( p ) (p + (d * 1x0) - 0x4) 3
							box (p + (0x1 * d) + 0x-4) (p + d) 3
						]
					][[]]
				)
				; edge
				line-width 1
				pen (border)
				fill-pen none
				box (p) (p + d) 3
				
			]
		
		
		vout
		
		; we just this word to save some word binding.
		blk
	]	
	
	
	;-----------------
	;-    prim-shadow-box()
	;
	; a depression from bg using a slight gradient fill
	;-----------------
	prim-shadow-box: func [
		p [pair!] "position"
		d [pair!] "dimension" ; does - 1x1 automatically
		w [integer!] "Shadow width"
		/colors 
			bg  [tuple! none!]
			border [tuple! none!]
		/all "put shadows on all four edges"
		/local 
			o ; offset (w*w)
			s ; start
			e ; end
			r ; right
			b ; bottom
	][
		vin [{prim-shadow-box()}]
		
		
		;d: d - 1x1
		
		o: 1x1 * w
		vo: 0x1 * w
		ho: 1x0 * w 
		s: p + o
		e: p + d 
		se: e + o
		
		sr: (e * 1x0) + (p * 0x1)
		sb: (e * 0x1) + (p * 1x0)
		
		blk: compose [
				
				line-width none
				
				pen none
				
				
;				fill-pen red
;				box (e) (se)
;				
;				fill-pen 255.255.255.128
;				box (sr) (se) 
				
				
				; right shadows
				fill-pen linear (sr + vo) 1 (w) 0 1 1 
					(0.0.0.200) 
					(0.0.0.240) 
					(0.0.0.255 )
				box (sr + vo) (se - vo)


				; bottom shadows
				pen none
				fill-pen linear (sb + ho) 1 (w) 90 1 1 
					(0.0.0.200) 
					(0.0.0.240) 
					(0.0.0.255 )

				box (sb + ho) (se - ho)


				; circular shadow at ends
				
				fill-pen radial (e) 0 (w) 0 1 1
					(0.0.0.200) 
					(0.0.0.240) 
					(0.0.0.255 )
				box (e) (se)

				fill-pen radial (sr + vo) 0 (w) 0 1 1
					(0.0.0.200) 
					(0.0.0.240) 
					(0.0.0.255 )
				box (sr) (sr + o)

				fill-pen radial (sb + ho) 0 (w) 0 1 1
					(0.0.0.200) 
					(0.0.0.240) 
					(0.0.0.255 )
				box (sb) (sb + o)

				; test edge
;				line-width 1
;				fill-pen none
;				pen gold
;				box (p ) (se) (w)
				
				
				
				
				
		
;				; top shadows
;				pen none
;				fill-pen linear (p + 1x1) 1 (5) 90 1 1 
;					(0.0.0.190) 
;					(0.0.0.235) 
;					(0.0.0.255 )
;
;				box (p + 1x1) (p + (d/x * 1x0) + 0x20) 3
;
;				; left shadows
;				fill-pen linear (p + 1x1) 1 (4) 0 1 1 
;					(0.0.0.200) 
;					(0.0.0.240) 
;					(0.0.0.255 )
;				box (p + 1x1) (p + (d/y * 0x1) + 4x0) 3
;				
;				(  either all [
;						compose [
;							; right shadows
;							fill-pen linear (p + d) 1 (4) 180 1 1 
;								(0.0.0.200) 
;								(0.0.0.240) 
;								(0.0.0.255 )
;							box (d * 1x0 + p ) (p + d - 4x0) 3
;							
;							; bottom shadows
;							fill-pen linear (p + (d )) 1 (4) 270 1 1 
;								(0.0.0.200) 
;								(0.0.0.240) 
;								(0.0.0.255 )
;							;box ( p ) (p + (d * 1x0) - 0x4) 3
;							box (p + (0x1 * d) + 0x-4) (p + d) 3
;						]
;					][[]]
;				)
;				; edge
;				line-width 1
;				pen (border)
;				fill-pen none
;				box (p) (p + d) 3
;				
			]
		
		
		vout
		
		; we just this word to save some word binding.
		blk
	]	

	
	;--------------------------------------------------------
	;-   
	;- LOW-LEVEL GLASS FUNCS
	;-----------------

	;-     layout()
	;-----------------
	; this is used to construct whole interfaces, based on a static specification.
	;
	; eventually, you will be able to generate SEVERAL WINDOWS at once!
	;
	; this is the basic entry point for SHINE (the Glass dialect)
	;
	; if within is specified, the spec will be applied to it.  any new marbles are ADDED to the frame
	; the only requirement is that the /within marble MUST be a frame.
	;
	; the layout func was move here since some marbles will need layout in their initialization.
	;-----------------
	layout: func [
		spec [block!]
		/within wrapper [word! object! none!] "a style name or an actual allocated marble, inside of which we will put new marbles."
		/using stylesheet [block!]
		/options wrapper-spec [block!] "allows you to supply a spec used when creating the wrapper itself."
		/only "do not automatically open a window if a !window is the wrapper (which it is by default)"
		/size sz [pair!]
		/center
		/tight "adds or creates a 'tight option to wrapper spec without need for options block."
		/local style guiface bx draw-spec filling wrap?
	][
		vin [{layout()}]
		vprobe spec
		
		
		; normalize stylesheet
		stylesheet: any [stylesheet master-stylesheet]
		
		
		;-------------------------
		; manage the wrapper
		;---
		; do we create a new top frame, or use specified wrapper and ADD new spec to it?
		switch type?/word wrapper [
;			object! [
;				; USE TOP MARBLE AS-IS
;				;within: wrapper
;			]
			
			word! none! [
				; either user specified or system default wrapper (eventually, default will be a 'window)
				style: any [wrapper 'window]
				
				; make sure the wrapper style exists.
				unless wrapper: select stylesheet style [
					to-error rejoin ["" style " type NOT specified in stylesheet"]
				]
				
				if all [
					style = 'window
					none? wrapper-spec
				][
					wrapper-spec: [tight]
				]
					
				
				; allocate a new wrapper.
				wrapper: alloc-marble/using wrapper wrapper-spec stylesheet
				wrap?: true
			]
		]
		
		
		;-------------------------
		; create the GUI
		;----
		; note that any item in the spec which precedes a marble name, will *eventually* be
		; used by the wrapper/gl-specify(), so you can set it up directly without needing to add special
		; refinements to layout.  :-)
		spec: reduce [spec]
		
		either wrap? [
			wrapper/valve/gl-specify/wrapper wrapper spec stylesheet
			wrapper/valve/gl-fasten wrapper

			; setup glob so it returns its draw block
			wrapper/glob/valve/reflect wrapper/glob [2 ]
		][
			wrapper/valve/gl-specify wrapper spec stylesheet
			wrapper/valve/gl-fasten wrapper

		]
		
		; if the wrapper is a window viewport, we automatically call its show .
		; this is the default layout mechanism.
		;
		; if you specify /only, we forego this step, and expect the application
		; to call its display method later on.
		
		if size [
			fill* wrapper/material/dimension sz
		]
		
		if all [
			not only
			in wrapper 'display
			in wrapper 'hide
		][
			vprint "I WILL DISPLAY WINDOW!!!"
			
			either center [
				wrapper/display/center
			][
				wrapper/display
			]
		]
		
		
		
		vout
		wrapper
	]

	;-----------------
	;-     alloc-marble()
	;-----------------
	alloc-marble: func [
		style [word! object!] "Specifying an object expects any marble, from which it will clone itself, a word is used to lookup a style from a stylesheet"
		spec [block! none!]
		/using stylesheet [block! none!] "specify a stylesheet manually"
		/local marble
	][
		vin [{glass/alloc-marble()}]
		stylesheet: any [stylesheet master-stylesheet]
		
		; resolve reference marble to use as the style basis.
		unless object? style [
			; make sure the wrapper type exists.
			unless marble: select stylesheet style [
				to-error rejoin ["" style " not in stylesheet"]
			]
			style: marble
		]
		
		; make sure the style really is a glass marble
		either all [
			object? style
			in style 'valve
			in style/valve 'style-name
		][
			; create the new marble instance 
			vprint "------ CREATE marble ------"
			marble: liquify* style
			
			vprint "------ SPECIFY marble ------"
			if spec [
				; spec might create inner marbles if the style is a group type marble and spec contains marbles.
				;
				; SPECIFY CAN MANIPULATE AND EVEN REPLACE THE SUPPLIED MARBLE... do not expect
				; the return marble to be the same as the one we supply to gl-specify.
				;
				marble: marble/valve/gl-specify marble spec stylesheet		
			]
			
		][
			to-error "Invalid reference style... not a glass marble!"
		
		]
		
		; cleanup GC
		style: spec: stylesheet: none
		
		vout
		marble
	]
	

	
	;-----------------
	;-     get-aspect()
	;-----------------
	get-aspect: func [
		marble
		item
		/or-material "this will also any material instead, if it exists"
		/plug "only return the plug of the aspect, not its value"
		/local p
	][
		vin [{get-aspect()}]
		vout
	
		all [
			any [
				; materials have precedence!
				if or-material [p: in marble/material item]
				p: in marble/aspects item
			]
			p: get p
			either plug [
				all [
					object? p
					in p 'valve ; is this really a plug?
					p
				]
			][
				content* p
			]
		]
		
	]
	
	
	
	
	
	;--------------------------------------------------------
	;-   
	;- LAYOUT HELPERS
	;-----------------
	;-     relative-marble?()
	; returns true if the supplied marble meets the conditions for managed relative positioning.
	;
	; basically, the marble needs an offset and a position material.
	;
	; the other prefered setup is that the position is within the aspect directly, and its not in the material.
	; which indicates that you are using absolute positioning.
	;-----------------
	relative-marble?: func [
		marble [object!]
		/true?
	][
		vin [{glass/relative-marble?()}]
		
		true?: all [
			in marble/aspects 'offset
			in marble/material 'position
			true
		]
		vout
		
		true?
	]
	

	;----------------------
	;-     wrap-lines()
	;
	; this is a VERY fast function, can be used within area or field type styles
	;----------------------
	wrap-lines: func [
		"Returns a block with a face's text, split up according to how it currently word-wraps."
		face "Face to scan.  It needs to have text, a size and a font"
		/local txti counter text
	][

		counter: 0
		txti: make system/view/line-info []
		while [textinfo face txti counter ] [
			counter: counter + 1
		]

		; free memory & return
		txti: none
		counter
	]

	
	
	;-----------------
	;-     sub-box()
	; returns a box which is a fraction of another box, using /orientation will
	; scale one of the coordinates to 100%
	;
	; min max are used to define the denominator of the fraction, amount is used to define
	; the numerator of the fraction
	;-----------------
	sub-box: func [
		box [pair!] 
		min [number!] "zero-based value"
		max [number!] "zero-based value"
		amount [number!] "zero-based value"
		/index "amount is an index within the range, instead of the visible part of range"
		/orientation ori [word! none!] "orientation of the box"
		/local range sub
	][
		;vin [{sub-box()}]
		
		
		;?? box
		;?? min
		;?? max
		;?? amount
		;?? ori
		range: max - min
		
		;?? range
		if index [
			amount: max 0 amount - min
		]
		scale: min* 1 any [
			all [range = 0 0]
			amount / range
		]
		
		;?? scale
		
		sub: switch/default ori [
			horizontal [
				;print "horizontal"
				;print box * scale
				max* (box * scale) (0x1 * box)
			]
			
			vertical [
				max* (box * scale) (1x0 * box)
			]
		][
			box * scale
		]
		
		;?? sub
		
		;vout
		sub
	]
	
	
	
	;-----------------
	;-     screen-size()
	;-----------------
	screen-size: func [
	][
		system/view/screen-face/size
	]
	
	
	
	
	
	
	;--------------------------------------------------------
	;-   
	;- STYLE MANAGEMENT
	;-----------------
	;-     collect-style()
	;-----------------
	; adds a marble style to a stylesheet, by default this is the master-stylesheet
	;-----------------
	collect-style: func [
		marble [object!]
		/into stylesheet [block!]
		/as style-name "this is actually encouraged, enforces style unicity"
		/local s old
	][
		vin [{glass/collect-style()}]
		vprint marble/valve/style-name
		
		s: any [stylesheet master-stylesheet]
		
		style-name: any [style-name marble/valve/style-name]
		
		; this is required to properly separate styles as separate entities completely.
		; not doing this allows quickly generated derivatives to share the valve, which isn't
		; very safe.  it could actually cause a derivative to highjack another style's 
		; valve.
		;
		; this may lead to dirty side-effect for inexperienced style creators.
		if as [
			marble: make marble [valve: make valve [] ]
			marble/valve/style-name: style-name
		]
		
		; add or replace style?
		if old: find s style-name [
			vprint "replacing old-style"
			remove/part old 2
		]
		append s style-name 
		append s marble
		
		s: stylesheet: old: none
		vout
		marble
	]
	
	
	;-----------------
	;-     list-stylesheet()
	;-----------------
	; simple abstraction for listing all styles in a stylesheet
	list-stylesheet: func [
		/using stylesheet [block! none!]
		/local rval
	][
		vin [{glass/list-stylesheet()}]
		stylesheet: any [stylesheet master-stylesheet]
		rval: extract stylesheet 2
		stylesheet: none
		vout
		
		rval
	]
	
	
	
	
	
	;--------------------------------------------------------
	;-  
	;- GUI SPEC MANAGEMENT
	;-----------------
	;-    regroup-specification()
	; take a spec block and break it up according to style names
	;
	; if items precede any recognized style name, they will be included at the root level of the returned spec.
	;-----------------
	regroup-specification: func [
		spec
		/using stylesheet [block!]
		/local s list gspec marble mode style-name set-word
	][
		vin [{glass/regroup-specification()}]
		s: any [stylesheet master-stylesheet]
		list: list-stylesheet/using stylesheet
		
		;?? list
		
		; create new grouped spec
		gspec: copy []
		marble: gspec
		
		; traverse all spec
		while [not empty? spec] [
			;item: first spec
			;print "--------------"
			;probe pick spec 1
			
			mode: none
			; is this a style name?
			mode: any [
				all [
					set-word? set-word: pick spec 1
					word? style-name: pick spec 2
					find list style-name
					'set-marble
				]
				all [
					word? style-name: pick spec 1
					find list style-name
					'marble
				]
			]
			;print mode
			switch/all mode [
				marble set-marble [
					; new marble starts here, create a new marble spec
					marble: copy []
					append/only gspec marble
				]
				set-marble [
					append/only marble pick spec 1
					spec: next spec
				]
			]
			append/only marble pick spec 1
			spec: next spec
		]
		
		s: marble: old: none
		vout
		gspec
	]
	

]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %sillica.r 
    date: 28-Jun-2010 
    version: 0.1.2 
    slim-name: 'sillica 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: SILLICA
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: EVENT  v1.0.6
;--------------------------------------------------------------------------------

append slim/linked-libs 'event
append/only slim/linked-libs [


;--------
;-   MODULE CODE



slim/register/header [

	view*: system/view

	;- LIBS
	;   
	!plug: liquify*: !glob: content*: fill*: link*: unlink*: detach*: retrieve-plug: none
	liquid-lib: slim/open/expose 'liquid none [
		!plug 
		retrieve-plug
		[liquify* liquify ] 
		[content* content] 
		[fill* fill] 
		[link* link] 
		[unlink* unlink] 
		[detach* detach]
	]
	
	glob-lib: slim/open 'glob none

	;-   
	;-  GLOBALS

	;-     last-move-position
	; remember last move coordinates so we can trigger it on time events.
	last-move-position: none
	
	
	;-     last-down-event
	; remember the mouse down event which switches moves to swipe/drop?
	last-down-event: none
	
	
	;-     last-move-event:
	; when mouse throttling is enabled, this is where we store mouse events until they are handled at
	; a time event.
	last-move-event: none
	
	
	;-     hold-count:
	; each time hold is called, this is incremented,
	; each time resume is called,  its decremented.
	;
	; resume will do nothing, if this is 0.  preventing the initial wait from terminating
	hold-count: 0
	
	
	;-     resume?:
	; if this is set to true, the wake event will kill the current wait loop.
	; note: will be ignored if hold-count < 1
	resume?: none
	
	
	;-     last-wake-event:
	; this event (object! or none!) is used to keep track of the CURRENT cloned event which triggered a dispatch.
	;
	; the reason we need this is to be able to refer to it when implementing dispatch-event
	; directives.
	;
	; that function will inspect the event/action to determine if its been directed to do 
	; something very low-level... like interrupt current event with a new wait,
	; or release of that interruption by returning none from itself.
	last-wake-event: none
	
	
	;-     immobile-start:
	; this is used to determine how many times the timer-based move event occured
	; its usefull to create an 'immobile action.
	immobile-start: none
	
	
	;-     GLASS-THROTTLE-MOUSE:
	; a global which tells this wake-event to postpone mouse events so they only occur just before time events.
	; 
	; be VERY carefull:
	;     -if you don't have any window with a rate, mouse handling is effectively nullified
	;     -key events might occur out-of order.
	;
	; its set as a global, since control of this must be application wide.
	set 'GLASS-THROTTLE-MOUSE true
	
	
	
	
	;-     focused-marble:
	; link any marble here so it receives focused keyboard events.
	;
	; focused keyboard events are triggered by the 'focus' input filter.
	focused-marble: liquify* !plug
	
	
	hot-keys: []
	
	
	;-     !event[]
	!event: context [
		;-         action:
		; current event type (it may evolve!)
		action: none          

		;-         marble:
		; stores the destination for the event, changes as streaming progresses.
		marble: none          

		;-         view-window:
		; what window face originated this event.
		view-window: none     

		;-         viewport:
		; stores the !viewport face which is responsible for this event.
		; note that in some setups, there may be several !viewports -> (<TO DO>: delayed feature)
		viewport: none        

		;-         coordinates:
		; where was the pointer when the event occured? (may evolve as we go from event->windows->marble)
		coordinates: none
		
		;-         offset:
		; above coordinates, converted to local offset, relative to position and 
		; frame transformations (translation/scale, if any)
		;
		; marble handlers will usually use this value instead of coordinates.
		;
		; note that windows/viewports are responsible for setting this value
		offset: none

		;-         key:
		; was the keyboard involved in the event?
		key: none            

		;-         control?:
		; was the control key pressed?
		control?: none        

		;-         shift?:
		; was the shift key pressed?
		shift?: none          

		;-         tick:
		; the event/time integer in milliseconds 
		; when the mouse is immobile over the active window,
		; move events are generated by view... we use this value
		; directly to create an 'immobile action (ticks usually happen twice a second)
		tick: none            
	]
	
	
	;-     event-queue:
	;
	; use the queue-event() function to add events here.
	;
	; used by the streaming engine to store created events while another event is being processed.
	; usually the queue will be empty.
	;
	; when an event is finished dispatching, the engine will see if there are new events in the queue
	; and start the process again.
	;
	; you can use the event-queue to re-order events...
	;
	; example:, a mouse click occurs.. you detect that the marble can be focused.
	; instead of managing the focus within the mouse handler... you generate new
	; unfocus & focus events.
	;
	; the stream engine will then start a new dispatch with the unfocus, and another with the focus.
	; this makes it possible for each part of glass to react to events, without requiring you to 
	; know how other systems manage events.
	;
	; when an event simply changes to another event type, just return the new (or modified) event
	; from the handler... no need to create a new event in this case.
	;
	; when the GLASS-THROTTLE-MOUSE is enabled, time events will use this system to stream the last stored
	; mouse event before the time event.
	event-queue: []


	;-     automation-queue:
	;
	; only used when playback? is true
	;
	; just like the event queue, but can be stalled by setting paused-playback? to true
	;
	; also, the queue is handled in a different way. we progress through the list one event
	; at a time and set the list to the next item (without removing anything)
	;
	; this way it can be paused and progress can resume at any time.
	;
	automation-queue: []
	
	
	;-     stream:
	; stores event processing functions.
	; the event library stream will be responsible for shooting off events to the window stream
	;
	; streaming allows us to implement various event manipulations in a decoupled manner.
	;
	; we can implement special features like hotkeys, add or even remove input events on the fly.
	;
	; the fact that windows have their own stream allows a good degree of flexibility.
	;
	; things like modality are handled within the stream.
	;
	; the stream handlers are labeled, for easy manipulation and reference.
	
	; you must use the various handler functions to manipulate this.
	stream: []
	
	
	;-     recording?:
	;
	; tells the core-glass-handler to start recording events.
	;
	; only root level (view) events are recorded, so any marble-generated events get processed normally.
	; and will stream as they should.
	;
	; recording is very handy to reproduce user interaction and allows developpers to automate testing
	; of new GUI features, to see if they perform as desired using a recorded event stream.
	;
	; a file storage/retrieval api is also provided, making it very easy to create a complete
	; solution for application macro, unit testing purposes, automated document generation and more
	;
	; you must not change window titles between recording and playback, nor should you modify
	; the layout between tests, cause things like mouse clicks will affect new marbles.
	recording?: false
	
	
	;-     record-events:
	;
	; tells the recording system what it should log.  
	;    true, means log everything.
	;    it can also be a block of event/action names to match
	record-events: true
	
	
	
	;-     event-log:
	; when recording is enabled, view events are stored here.  we can run automate on the list after
	;
	; 'activate events are stored as activate-window events instead, which allow the engine to
	; CAUSE a window activation instead.
	event-log: []
	
	
	;-     playback?:
	; enables automation playback, prevents new event recording, and post-pones normal event processing.
	;
	; causes the wake-even() to call do-automation() instead of real events.
	;
	; normally queued events cannot be interrupted (events triggered by marbles which end up in event-queue) but once all
	; queued-events are done, the next automation event may be stalled, see paused-playback?: below.
	;
	playback?: false
	
	
	;-     paused-playback?:
	;
	; interrupts the automation playback when set to true.
	;
	; because time events occur normally, the queue will be verified periodically.
	;
	; note that to set the value of paused-playback? you need to have an external control
	; over the GLASS application.  this is commonly done using a normal view window
	; or tcp port as a trigger.
	paused-playback?: false
	
	
	;-     play-delay:
	; when dispatching an automation, wait this time period before continuing.
	;
	play-delay: 0.2
	
	
	
	
	;-   
	;- FUNCTIONS
	
	
	;-----------------
	;-     clone-event()
	;
	;  note: /with block! only works with object! events
	;-----------------
	clone-event: func [
		event [object! event!]
		/with e [event! block!] "when cloning !event objects, transfer event! type values into it"
	][
		if event? event [
			; this is an internal view event!
			e: event
			event: !event
		]
		
		; clone the glass event.
		either block? e [
			event: make event e
		][
			event: make event []
		]
		
		; carry over any view event properties into glass
		if event? e [
			event/coordinates: e/offset
			event/key: e/key
			event/action: e/type
			; be carefull because at different stages, this face can change, especially
			; if there are multiple !VIEWPORTs in a single window.
			event/view-window: e/face
			event/control?: e/control
			event/shift?: e/shift
			event/tick: e/time
;			if e/type = 'down [
;				print ["event/ticks: " e/time]
;				print ["event/ticks: " event/tick]
;			]
		]
		event
	]
	
	
	
	;-----------------
	;-     queue-event()
	; 
	; add specified event on the queue.
	;-----------------
	queue-event: func [
		event [object! block!]
		/automated "add to automation queue instead, used by recording and direct call to automated"
	][
		vin [{queue-event()}]
		;print "QUEUING EVENT!"
		if block? event [
			event: clone-event/with !event event
		]
		
		
		either in event 'action [
			append either automated [automation-queue][event-queue] event
		][
			to-error "GLASS/Event.r/queue-event() ATTEMPT TO QUEUE INVALID OBJECT!"
		]
		vout
	]
	
	
	;-----------------
	;-     make-event()
	;-----------------
	make-event: func [
		spec [block!]
	][
		;vin [{make-event()}]
		make !event spec
		
	]
	
	;-----------------
	;-     flush-queue()
	;-----------------
	flush-queue: func [
	][
		vin [{flush-queue()}]
		clear event-queue
		vout
	]
	
	
	
	
	;-----------------
	;-     do-queue()
	;-----------------
	do-queue: func [
		/local gl-event trigger trigger-action
	][
		;vin [{do-queue()}]
		
		; process normal queue
		until [
			if gl-event: pick event-queue 1 [
				either trigger: get in gl-event 'event-trigger [
					switch/default type?/word trigger [
						date! [
							
							either now/precise > trigger [
								;print "event-triggered event!"
								;print "done"
								if trigger-action: get in gl-event 'event-trigger-action [
									;probe action
									do trigger-action
								]
								remove event-queue
								dispatch gl-event
							][
								;print "skipped"
								event-queue: next event-queue
							]
						]
					][
						remove event-queue
						dispatch gl-event
					]
				][
					remove event-queue
					dispatch gl-event
				]
			
			]
			
			empty? event-queue
		]
		; in case we skipped some un-triggered events
		event-queue: head event-queue
		;vout
	]
	
	
	
	
	;-----------------
	;-     handle-stream()
	;
	; adds/replaces a handler in an event stream
	; 
	; be carefull, this function is called for EVERY event
	;
	; if your handler needs any persistent values, wrap the function within
	; a context, and call handle-stream from within the context.
	;
	; be carefull, if the named handler already exists, it WILL be replaced.
	;-----------------
	handle-stream: func [
		name [word!]
		handler [function!]
		/before bhdlr [word!] "add before handler"
		/after ahdlr [word!] "add after handler"
		/within strm [block! object!] "add a handler to a marble or viewport"
	][
		vin [{add-handler()}]
		either (copy/part third :handler 2) = compose/deep [event [(object!)]] [
			vprint "HANDLER COMFORMS!"
			
			; use glass stream or marble's own stream
			strm: any [strm stream]
			
			; reuse or create a new stream for a specified marble
			if object? strm [
				; object MUST be a marble
				strm: strm/stream: any [strm/stream copy []]
			]
			
			;vprint length? strm
			
			
			append strm name
			append strm :handler
			
		][
			vprobe  (copy/part third :handler 2)
			to-error "GLASS/Event.r/add-handler() requires first argument to be event [object!]"
		]
		vout
	]
	
	
	;-----------------
	;-     bypass-stream()
	; removes a handler from an event stream
	;-----------------
	bypass-stream: func [
		name [word!]
		/from strm [block!]
	][
		vin [{bypass-stream()}]
		strm: any [strm stream]
		vout
	]
	
	

	;-----------------
	;-     do-automation()
	;-----------------
	do-automation: func [
		/local gl-event
	][
		vin [{do-automation()}]
		unless paused-playback? [
			until [
				
				; get automation event 
				if gl-event: pick automation-queue 1 [
					;print ["^/---------------^/automation events left: " length? automation-queue]
					;probe gl-event/action
					;print ["^/---------------^/event log: " length? event-log]
					
					remove automation-queue
					
					wait play-delay
					dispatch clone-event gl-event
					
					; trigger wake-event... smoother for view?
					wait 0
					
					; the automated event might have generated queued events.
					;print ["^/---------------^/queue: " length? event-queue]
					do-queue
				]
				
				; are we done?
				any [
					paused-playback? ; automation was interrupted
					empty? automation-queue ; all done
				]
			]
			
			; disable automation and reset automation-queue to its head.
			if empty? automation-queue [
				; we're done!
				reset-automation
			
			]
		]
		
		
		vout
	]
	
	

	
	;-----------------
	;-     automate()
	;
	; given a block of events or event block specs, perform each event using specified delay
	;
	; any events triggered by wake-event will be ignored, exception of time events.
	;
	; when automate is called, playback? is set to true and wake-event will start to ignore
	; its own events.
	;
	; setting paused-playback? will stop do-automation from processing its queue, 
	; giving wake-event the chance to re-trigger it on time events.
	;-----------------
	automate: func [
		events [block!]
		delay [integer! decimal!]
		/paused
		/local event
	][
		vin [{automate()}]
		
		reset-automation
		foreach event events [
			queue-event/automated event ; /automated will add the event to automation-queue
		]
		playback?: true
		paused-playback?: paused ; make sure we don't start paused by default, but allow as an option.
		
		play-delay: delay
		do-automation
		vout
	]
	
	;-----------------
	;-     reset-automation()
	;
	; quits playback, clears automation-queue to its head and exits pause mode.
	;
	; doesn't touch event-log, since that is specifically recording related.
	;-----------------
	reset-automation: func [
		
	][
		vin [{reset-automation()}]
		playback?: false
		
		paused-playback?: false
		
		automation-queue: head clear head automation-queue
		vout
	]
	
	
	
	
	;-----------------
	;-     start-recording()
	;
	; enables event logging, also resets the log, if already recording
	;
	; note that we do not record time events, since they will only 
	; generate noise.   normal time ticks will occur as usuall once
	; playback is started, so any time sensitive events will still
	; occur, but have current time instead of original time.
	;
	; refresh rate is also independent of recording, so you can record at
	; high-rate, slow down refresh, then playback.
	;
	; this ultimately allows you to run the playback at cpu speed, if its not
	; dependent on time information. 
	;
	; /only allows you to specify a list of event/action types you wish to remember
	;       note that the block is NOT copied and may be modified at runtime
	;-----------------
	start-recording: func [
		/only events [block! word!]
	][
		vin [{start-recording()}]
		
		; flush event log
		event-log: copy []
		
		; pause play
		stop-playback
		
		; set recording stat to true
		recording?: true
		
		if only [
			if word? events [
				events: compose [(events)]
			]
			record-events: events
		]
		
		vout
	]
	
	
	;-----------------
	;-     record-event()
	;
	; depending on event types, we record event or not.
	;
	; only events generated by view whould be submitted here.
	;-----------------
	record-event: func [
		event [object!] "This must be a COPY of original !event object"
	][
		vin [{record-event()}]
		
		; we ignore useless time events.
		either event/action = 'time [
			;prin "."
		][
			
			
			switch/default event/action [
				move key down up [
					append event-log event
				]
				; these events CAUSE activation to change.  we use different action names, to make sure
				; no activate cycle is caused. (just like resizing "feedback")
				active [
					event/action: 'ACTIVATE-WINDOW!
					append event-log event
				]
				inactive [
					event/action: 'DEACTIVATE-WINDOW!
					append event-log event
				]
				resize [
					event/action: 'RESIZE-WINDOW!
					; the coordinates are the actual mouse position while resizing window,
					; so we change the value for the window's new size
					event/coordinates: event/view-window/size
					append event-log event
				]
				offset [
					event/action: 'MOVE-WINDOW!
					; the coordinate is the actual mouse position while dragging window
					; we substitute the value for new offset
					event/coordinates: event/view-window/offset
					append event-log event
				]
			][
				;print "Not recording:"
				;print event/action
				;print event/coordinates
			]
		]
		vout
	]
	
	
	
	
	;-----------------
	;-     stop-recording()
	;-----------------
	stop-recording: func [
	][
		vin [{stop-recording()}]
		recording?: false
		vout
	]
	
	
	
	
	;-----------------
	;-     pause-recording()
	;-----------------
	pause-recording: func [
		
	][
		vin [{pause-recording()}]
		vout
	]
	
	
	;-----------------
	;-     store-recording()
	;
	; allows you to store a recording for later retrieval using the restore-recording.
	;
	; note that the view-window property must be wiped out when an automation is stored. 
	; we replace it with the window's title.
	;
	; when the recording is later restored, we try to match the Title with any opened window,
	; if any are opened. 
	;
	; if none matched (usually cause they are not yet opened), we delay the process, and 
	; let do-automation map it out a run-time.
	;
	; note: event/ticks are not cleared at this time.  its possible that this could be a 
	;       slight privacy risk since someone could determine time of event by scanning file.
	;
	;       in a further release, we could anonymise this by calculating an offset from first
	;       tick wrt every other, and then restore current tick time when do-automation is performed.
	;-----------------
	store-recording: func [
		/name filename [word! file! url!]
		/safe "do not overwrite previous recording!"
		/local file event
	][
		vin [{store-recording()}]
		;print "STORE RECORDING!"
		if word? filename [
			filename: to-file join to-string filename ".gler" ; gler = glass event recording.
		]
		
		filename: any [filename %glass-event-recording.gler]
		
		
		if all [
			safe
			exists? filename
		][
			; <TO DO>  pop up a requestor instead?
			; error is meant to make it easier to trap when debugging.
			to-error "GLASS tried to overwrite event recording, but application asked not to!"
		]
		
		; make sure we have access to disk or url
		if file: attempt [write filename "" copy ""] [
			
			foreach event event-log [
				; replace window by its title
				event/view-window: event/view-window/text
				
				; clear fields which will be filled out by core handler (if they are filled for some reason)
				event/viewport: none
				
				
				; event
				append file mold/all event
			
			]
			
			write filename file
			
		]
		vout
	]
	
	
	;-----------------
	;-     restore-recording()
	;-----------------
	restore-recording: func [
		/name filename [word! file! url!]
		/local window windows item
	][
		vin [{restore-recording()}]
		filename: any [filename %glass-event-recording.gler]
		v?? filename

		if word? filename [
			filename: to-file join to-string filename ".gler" ; gler = glass event recording.
		]

		if attempt [
			if exists? filename [
				data: load filename
			]
		][
;			probe data
;			print "!!!!!!!!!!!!!!!!!!!!!!!!!"
;			probe type? system/view/screen-face/pane
;			print "!!!!!!!!!!!!!!!!!!!!!!!!!"
;			print length? system/view/screen-face/pane
;			probe windows
			windows: copy []
			foreach window system/view/screen-face/pane [
				;print window/text
				append windows window/text
				append windows window
			]
			; attempt to re-link window to its title right away
			foreach item data [
				if window: select windows item/view-window [
					;print "window title match!"
					item/view-window: window
				]
			]
		]
		event-log: data
		clear windows
		windows: item: window: data: none
		
		vout
	]
	
	
	
	;-----------------
	;-     set-recording()
	;-----------------
	set-recording: func [
		
	][
		vin [{set-recording()}]
		vout
	]
	
	
	
	;-----------------
	;-     stop-playback()
	;-----------------
	stop-playback: func [
		
	][
		vin [{stop-playback()}]
		reset-automation
		vout
	]
	
	
	
	
	;-----------------
	;-     playback-recording()
	;-----------------
	playback-recording: func [
		/speed spd [integer! decimal!]
	][
		vin [{playback-recording()}]
		
		recording?: false
		
		; tells the engine to ignore new events we might cause.
		; example, moving mouse over window will not be recognised while playback occurs.
		playback?: true
		
		; make sure we're not paused.
		paused-playback?: false
		
		spd: any [spd 0.05]
		
		
		vprobe length? event-log
		vprobe length? automation-queue
		automate event-log spd
		vout
	]
	
	
	
	
	
	
	

	
	;-----------------
	;-     marble-at-coordinates()
	;
	; the nitty gritty function which converts a color from an image at a specific offset
	; and returns the associated liquid plug.
	;
	; note that the image size and range of offset must match exactly.
	;  if you specify coordinates which are out of bounds, an error or wrong plug WILL happen.
	;-----------------
	marble-at-coordinates: func [
		image [image!]
		offset [pair!]
	][
		retrieve-plug glob-lib/to-sid pick image offset/y + 1 * image/size/x + offset/x
	]
	
	
	
	;-----------------
	;-     coordinates-to-offset()
	;
	; given a marble and coordinates, will return the offset of the coordinates
	; to that marbles's position, including ALL parent transformation by panes or
	; otherwise.
	;
	; currently, only translation is managed, but we might add scaling at some point.
	; this would be very usefull for some applications.
	;
	; translation is calculated by moving up the frame stack and collecting any
	; marble/material/translation attributes it finds, adding them all up and
	; removing that from the given coordinate
	;
	; this function is intended for use by the event mechanism.
	;
	; <TO DO> accelerate the process by using some kind of marble cache which stores
	;         collected translation nodes.
	;
	;         this process will have to be managed by the collect/discard/fasten process
	;         but must be optimal so it doesn't get re-applied at each level of a collect
	;         tree of frames.  otherwise it would be exponentially slow as frames are layered
	;         deeper and deeper.
	;
	;
	; note that for now, the function is SAFE in that is checks datatypes, while
	; development ensues, but at some point, it will become unsafe and will
	; expect the translations to be setup properly, or not at all.
	;  
	; this will speedup lookup a bit, but should not account for much speed gains.
	; the current implementation is already sufficiently fast for R/T interactivity.
	;
	;-----------------
	coordinates-to-offset: func [
		marble [object!]
		coordinates [pair!]
		/local offset w frm position
	][
		;vin [{coordinates-to-offset()}]
		;print ""
		;?? coordinates
		position: content* marble/material/position
		;?? position 
		offset: coordinates - position
		
		;?? offset
		if frm: marble/frame [
			until [
				if object? w: get in frm/material 'translation [
					;if object? w: get w [
						if pair? w: content* w [
							;?? w
							offset: offset - w
						]
					;]
				]	
				if object? w: get in frm/material 'translation-origin [
					;if object? w: get w [
						if pair? w: content* w [
							;?? w
							offset: offset - w
						]
					;]
				]	
;				if object? w: get in frm/material 'inner-offset [
;					probe "found inner-offset"
;					;probe 
;					;if object? w: get w [
;						if pair? w: content* w [
;							?? w
;							offset: offset + w
;						]
;					?? offset
;					;]
;				]	
				none? frm: frm/frame
			]
		]
		;?? offset
		;vout
		
		offset
	]
	
	
	
	;-----------------
	;-     offset-to-coordinates()
	;
	; this takes a marble, an offset from it and returns the window
	; coordinates which map to it.
	;
	; its usefull to translate the transformation matrix from one arbitrary
	; marble to another, or to position things globally relative to a marble,
	; like in popups, on reveal().
	;
	; note that for now, the function is SAFE in that is checks datatypes, while
	; development ensues, but at some point, it will become unsafe and will
	; expect the translations to be setup properly, or not at all.
	;  
	; this will speedup lookup a bit, but should not account for much speed gains.
	; the current implementation is already sufficiently fast for R/T interactivity.
	;-----------------
	offset-to-coordinates: func [
		marble [object!]
		offset [pair!]
		/local coordinates w frm position
	][
		vin [{offset-to-coordinates()}]
		;print ""
		;?? coordinates
		position: content* marble/material/position
		;?? position 
		coordinates: offset + position
		
		;?? offset
		if frm: marble/frame [
			until [
				if w: in frm/material 'translation [
					if object? w: get w [
						if pair? w: content* w [
							;?? w
							coordinates: coordinates + w
						]
					]
				]	
				if w: in frm/material 'translation-origin [
					if object? w: get w [
						if pair? w: content* w [
							;?? w
							coordinates: coordinates + w
						]
					]
				]	
				none? frm: frm/frame
			]
		]
		;?? offset
		;vout
		
		coordinates
	]
	
	
	
	
	
	;-     WAKE-EVENT()
	view*/wake-event: func [
		port 
	] bind [
		;event: pick port 1
		if resume? [
			resume?: false
			if hold-count > 0 [
;				probe " - WILL RESUME FROM INTERRUPTION - "
				hold-count: hold-count - 1
				;queue-event compose [viewport: (last-wake-event/viewport) action: 'resume]
				return true
			]
		]

		dispatch-event pick port 1	
	] in view* 'self

;		; not shure if this is EVER triggered!
;		if none? event [
;			return false
;		]
;		
;		;----------------------------------
;		; kill-wait, feature on hold
;		;
;		; basically an event handler interrupt
;		;
;		; this is used to allow faces to use wait so faces within a window may act as modal actions.
;		; event blocking in main window is up to the face to handle, but now, at least the function
;		; calling the popup can return a value directly.
;		;
;		; this allows for "cancel" boxes in some difficult circumstances or things like
;		; network handlers which can interfere with the GUI, causing a modal popup to close
;		; by itself, when an async xfer is done.
;		;
;		; needs testing to be re-instated within GLASS
;;		if value? 'kill-wait? [
;;			if kill-wait? [
;;				kill-wait?: none
;;				return true
;;			]
;;		]
;		
;		;
;		
;		
;		;-          -Mouse move throttling
;		; prevents glass from accumulating mouse events when its not feasible.
;		; mouse events will then be sent just before the next time event.
;		;
;		; this immediately tunes the maximum mouse rate to the refresh rate of your app.
;		;
;		; since mouse events are always sent just before the time events, this also optimises
;		; refresh to a single redraw per mouse move.
;		;
;		; with the liquid propagate() optimisation, this is less valuable than it used to be.
;		; but with a graphic application this can still make a big difference
;		if GLASS-THROTTLE-MOUSE [
;			if event/type = 'move [
;				move-event: event
;				return empty? screen-face/pane
;			]
;			
;			if event/type = 'time [
;				if move-event [
;					do move-event
;				]
;				do event
;				move-event: none
;			
;				return empty? screen-face/pane
;			]
;		]
;
;;		if event/type = 'key [
;;			; since we're going to do it anyways in edit-text, The algorythm has changed,
;;			; in order to allow mapped keys to be given to the hot-key handlers.
;;			mapped-key: map-keys event
;;			
;;			
;;			; use add-hotkey-handler to enable application-wide hotkeys.
;;			; these are not called within poped-up windows.
;;			if all [gbl-hotkeys empty? pop-list][
;;				if hot-action: select gbl-hotkeys mapped-key [
;;					consumed?: hot-action face event key 	; NB at this level, face is the window. use top-face, and win-offset, 
;;															; like the scrollwheel does below to react localy to whatever is under
;;															; the mouse when you press the hotkey.
;;				]
;;			]
;;			
;;		]
;
;		
;
;		; this is just to cure bugs which don't refresh some view internals when do event isn't called on the 
;		; window after a window-related events.
;		;
;		; the bug leaves the window face at its previous state, even though the window has resized, moved, etc.
;		if find [resize offset] event/type  [
;			;print "###############################"
;			;print event/type
;			;ask ""
;			; following line is basically a no-op, since window has no feel
;			do event
;		]
;
;		;-          -Event streaming
;		gl-event: clone-event event
;		
;		
;		either playback? [
;			; make sure the interface refreshes when playback is activated.
;			either find [time resize offset] gl-event/action [
;				consumed?: not dispatch gl-event
;				do-queue
;			][
;				; run
;				;do-automation
;			
;				;we consume all events during playback, for now
;				none
;			]
;			
;		][
;			if recording? [
;				; store a copy of the original event
;				rec-event: make gl-event []
;			]
;			
;			consumed?: not dispatch gl-event
;			
;			if gl-event/action = 'time [
;				;prin "."
;			]
;			
;			if recording? [
;				if rec-event/action <> 'time [
;					;print "^/-------------"
;					;print "??"
;					;print type? gl-event/viewport
;					unless any [
;						none? gl-event/viewport ; we don't record events which don't concern GLASS
;						
;					][
;						record-event rec-event
;					]
;				]
;			]
;			
;			; check queue
;			do-queue
;		]
;		;v?? consumed?
;		;vprint type? event
;
;
;		;------------
;		; provide minimal VID/View compatibility
;		;
;		; note that VID interaction might be affected, since it is called AFTER
;		; glass streaming.
;		;
;		; note that the whole VID pop-up system is deactivated when using GLASS...
;		; only normal windows will continue to function.
;		unless consumed? [
;			 
;;			either pop-face [
;;				if in pop-face/feel 'pop-detect [event: pop-face/feel/pop-detect pop-face event]
;;				do event
;;				found? all [
;;					pop-face <> pick pop-list length? pop-list
;;					(pop-face: pick pop-list length? pop-list true)
;;				]
;;			] [
;;	
;;				unless consumed? [
;					do event
;;				]
;;			]
;		]
;		
;		; following line might be replaced by something more controlable
;		empty? screen-face/pane
;				
;	] in view* 'self
;	
;	


	;-----------------
	;-     hold()
	;
	; interrupts interpreter, while a new event loop is handled.
	;
	; use resume to break the interruption
	;-----------------
	hold: func [
	][
		vin [{interrupt()}]
		if last-wake-event [
			hold-count: hold-count + 1
			wait []
		]
		vout
	]
	
	;-----------------
	;-     resume()
	;
	; tell the wake event to quit last event loop.
	;-----------------
	resume: func [
	][
		vin [{resume()}]
		resume?: true
		vout
	]
	
	


	;-----------------
	;-     dispatch()
	;
	; note: this function will eventually be optimised for speed, for now its kept
	;       as readable as can be, cause debugging events is quite complex.
	;-----------------
	dispatch: func [
		event [object!]
		/local handlers handle 
			rval ; used temporarily, will eventually be eliminated
	][
		;vin [{dispatch()}]
		
		; takes an event and streams it all the way to an actual marble.
		;
		; basicaly it runs every function in the streams until one returns something else than an object.
		;
		; false or none is just an indication to stop (event is consumed)
		; event-handlers might actually create new events which will be added in the event-queue.
		; wake-event will call dispatch until the queue is empty.
		;
		; the event you return from a handler is the one which is used, so it might actually be
		; a different object, with more properties or even of a different action type.
		;
		; a single call to dispatch manages all three streams (glass, window, marbe).  this is
		; to promote a unity in the management of events... we could have added a dispatch for 
		; window and another for marbles, but then every stylist might create new dispatch models.
		; this isn't in the best interest of the end-programer.
		
		;--------
		; manage glass stream
		
		; skip labels
		handlers: next stream
		
		;vprobe event/action
		
		;vprint "glass stream"
		until [
			;vprint "handlers left:"
			;vprint length? handlers
			not if handle: pick handlers 1 [
				;vprint "HANDLING EVENT IN GLASS"
				; handle is a function!
				event: handle event
				
				; skip handler labels
				handlers: skip handlers 2
				
				not event
			]
		]
		
		
		;--------
		; manage window stream
		; part of the glass stream is to identify the viewport


		;vprint "viewport stream"
		;vprint type? event
		if all [
			event
			event/viewport
			; skip label
			handlers: next event/viewport/stream
		] [
			until [
				not if handle: pick handlers 1 [
					;vprint "HANDLING EVENT IN VIEWPORT"
					
					event: handle event
					handlers: skip handlers 2
					
					not event
				]
			]
		]		
		
		;--------
		; manage marble stream
		; part of the viewport stream's job is to identify the marble.
		;
		; by default the extremely fast backplane method is used.
		;vprint "marble stream"
		;vprint type? event
		if all [
			event
			event/marble
			in event/marble 'stream
			block? event/marble/stream
			handlers: next event/marble/stream
		][
			until [
				not if handle: pick handlers 1 [
					event: handle event
					handlers: next handlers
					
					not event
				]
			]
			
		]
		
		
;		vprint type? event
;		if event [
;			if event/marble [
;				; we ended up at a marble, 
;				event: none
;			]
;		]
;		
;		
;		; if the event is fully consumed by any handler, or we encounter a viewport
;		; it means glass was the intended target of the event.
;		if event [
;			either all [
;				event/viewport
;				
;			][
;				none
;			][
;				event
;			]
;		]
		
		
		; there are three types of return values for dispatch
		;    1) un-managed events (GLASS didn't handle the event itself, so its meant for another gui (VID?))
		;    2) none.  event is consumed, do nothing with it.
		;    3) directives, packaged as special event/actions which the wake-event understands.
		;
		; directives may only be used from within an event dispatched by wake-event itself.
		; this means you MAY NOT queue directives.
		rval: all [
			event
			any [
				; directives
				event/action = 'interrupt ; causes a modal wait
				event/action = 'continue ; frees the interrupt
					
				; was event meant for a GLASS window?
				not event/viewport
			]
			
			
			; we return event only if all prior conditions expect us to do so
			event
		]
		
		;vout
		rval
	]
	
	
	;-----------------
	;-     dispatch-event()
	;
	; used directly by wake-event, but can also be used manually.
	;-----------------
	dispatch-event: func [
		event
	] bind [
		
		; not shure if this is EVER triggered!
		if none? event [
			return false
		]
		
		;----------------------------------
		; kill-wait, feature on hold
		;
		; basically an event handler interrupt
		;
		; this is used to allow faces to use wait so faces within a window may act as modal actions.
		; event blocking in main window is up to the face to handle, but now, at least the function
		; calling the popup can return a value directly.
		;
		; this allows for "cancel" boxes in some difficult circumstances or things like
		; network handlers which can interfere with the GUI, causing a modal popup to close
		; by itself, when an async xfer is done.
		;
		; needs testing to be re-instated within GLASS
;		if value? 'kill-wait? [
;			if kill-wait? [
;				kill-wait?: none
;				return true
;			]
;		]
		
		;
		
		
		
		;-          -Mouse move throttling
		; prevents glass from accumulating mouse events when its not feasible.
		; mouse events will then be sent just before the next time event.
		;
		; this immediately tunes the maximum mouse rate to the refresh rate of your app.
		;
		; since mouse events are always sent just before the time events, this also optimises
		; refresh to a single redraw per mouse move.
		;
		; with the liquid propagate() optimisation, this is less valuable than it used to be.
		; but with a graphic application this can still make a big difference
		if GLASS-THROTTLE-MOUSE [
			if event/type = 'move [
				last-move-event: event

				; the generic end of windowed application return value
				return empty? screen-face/pane
			]
			
			if event/type = 'time [
				; execute move out of order.
				if last-move-event [
					; we only verify if the manage-event returned TRUE, which means to stop the wake-event.
					; any other return value is ignored.
					;
					; this allows us to build a situation where mouse moves may be the cause for
					; resuming from an interrupt (moving out of modal menu)
					either true =  manage-event last-move-event [
						return true
					][
						do event
					]
					last-move-event: none
				]
			]
		]

;		if event/type = 'key [
;			; since we're going to do it anyways in edit-text, The algorythm has changed,
;			; in order to allow mapped keys to be given to the hot-key handlers.
;			mapped-key: map-keys event
;			
;			
;			; use add-hotkey-handler to enable application-wide hotkeys.
;			; these are not called within poped-up windows.
;			if all [gbl-hotkeys empty? pop-list][
;				if hot-action: select gbl-hotkeys mapped-key [
;					consumed?: hot-action face event key 	; NB at this level, face is the window. use top-face, and win-offset, 
;															; like the scrollwheel does below to react localy to whatever is under
;															; the mouse when you press the hotkey.
;				]
;			]
;			
;		]

		manage-event event


				
	] in view* 'self
	
	
	;-----------------
	;-     manage-event()
	; the low-level event handling code.
	;
	; this causes high-level dispatch as well as controls application of event directives.
	;
	; this was previously part of dispacth-event(), but ended up being required twice in that
	; same function, so it was ripped out.
	;
	; note that our return value ends up being used DIRECTLY by wake-event.
	;-----------------
	manage-event: func [
		event
		/local consumed? gl-event rec-event
	] bind [
		; this is just to cure bugs which don't refresh some view internals when do event isn't called on the 
		; window after a window-related events.
		;
		; the bug leaves the window face at its previous state, even though the window has resized, moved, etc.
		if find [resize offset] event/type  [
			; following line is basically a no-op, since glass windows have no face/feel
			do event
		]

		;-          -Event streaming
		gl-event: last-wake-event: clone-event event
		
		
		either playback? [
			; make sure the interface refreshes when playback is activated.
			either find [time resize offset] gl-event/action [
				consumed?: not dispatch gl-event
				do-queue
			][
				; run
				; do-automation
			
				; we consume all events during playback, for now
				none
			]
			
		][
			if recording? [
				; store a copy of the original event
				rec-event: make gl-event []
			]
			
			consumed?: not dispatch gl-event
			
			;-          -Directives
			switch gl-event/action [
				; uncomment while debugging.
;				time [
;					prin "-->"
;					;wait none
;				]
				
				; causes a modal break in event handling.
				; this starts a new event loop on the stack.
;				interrupt [
;					PROBE "##################################################################"
;					 halt
;					PROBE "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"
;				]
				
				; frees the modal hold
				; breaks the current event loop, returning to the stack, from last hold
				;
				; the resume() function has a nifty "resume overun" protection.  always use it in code.
				;
				; this ensures that if one too many resumes is called, though this should be considered a bug, 
				; the application won't close unexpectedly.
				; 
				resume [
					return true
				]
			]
			
			if recording? [
				if all [
					rec-event
					rec-event/action <> 'time
					any [
						; we are recording EVERYTHING
						true = record-events
						
						; we listed a few events to capture.
						find record-events rec-event/action
					]
				][
					;print "^/-------------"
					;print "??"
					;print type? gl-event/viewport
					unless any [
						none? gl-event/viewport ; we don't record events which don't concern GLASS
						
					][
						record-event rec-event
					]
				]
			]
			
			; check queue
			do-queue
		]
		;v?? consumed?
		;vprint type? event


		;------------
		; provide minimal VID/View compatibility
		;
		; note that VID interaction might be affected, since it is called AFTER
		; glass streaming.
		;
		; note that the whole VID pop-up system is deactivated when using GLASS...
		; only normal windows will continue to function.
		unless consumed? [
			 
			either pop-face [
				if in pop-face/feel 'pop-detect [event: pop-face/feel/pop-detect pop-face event]
				do event
				found? all [
					pop-face <> pick pop-list length? pop-list
					(pop-face: pick pop-list length? pop-list true)
				]
			] [
	
;				unless consumed? [
					do event
;				]
			]
		]
		
		; following line might be replaced by something more controlable
		empty? screen-face/pane
	] in view* 'self
	
	
		
	;-----------------
	;-     dispatch-event-port()
	;
	; this manually grabs all events at event port and dispatches them thru glass event manager.
	;
	; using this function, we can dispatch events which are waiting even if we are
	; processing.  because system events like resize window or activate, will only trigger
	; once our processing is finished, which isn't very user friendly.
	;-----------------
	dispatch-event-port: func [
		/local event
	][
		vin [{dispatch-event-port()}]
		until [
			event: pick system/view/event-port 1
			
			dispatch-event event
			
			not event
		]
		vout
	]
	
	
	
	
	;-  
	;- HANDLER
	; add default handler(s) to glass
	; we wrap them in a context, so we don't pollute global space.
	context [
	
		; we define any locals here, so they don't get managed at each function call.
		viewport: none
	
		;-     tooltip-marble:
		; when a tooltip is shown, put its pointer here so we know to remove it later and 
		; to remember that we should only call a tooltip once.
		tooltip-marble: none
		
		;-     focused-marbles:
		; we store all focused marbles here
		; 
		; any text-input will then be forwarded to them. 
		focused-marbles: []
		
		;-     character-map-table:
		; this should eventually be part of the api.
		character-map-table: [
			#"^[" escape
			#"^M" enter
			#"^-" tab
			#"^~" erase-current  ; delete-key
			#"^H" erase-previous ; backspace key
			"ctrl+^~" erase-all
			"ctrl+shift+right" move-to-next-word
			"ctrl+right" move-to-next-word
			"ctrl+shift+left" move-to-previous-word
			"ctrl+left" move-to-previous-word
			#"^A" select-all
			#"^V" paste
			#"^C" copy
			#"^X" cut
			right move-right		
			left move-left
			up move-up
			down move-down
			home move-to-begining-of-line
			end move-to-end-of-line
		]
		
		
		;-     fast-click-delay:
		; set this in milliseconds
		fast-click-delay: 500
		
		;-     last-click:
		; stores moment of last mouse down
		; when it is below delay, the following down events have their 'fast-clicks attribute set to something else than none
		last-click: 0
		
		;-     fast-clicks?:
		; if the mouse down was a fast click, set this to true
		; further cliks will check and will increment the fast-click count until one goes beyond delay
		fast-clicks?: none
		
		
		
		context [
		
			compound-key-code: none
		
			;-     core-glass-handler()
			handle-stream 'core-glass-handler func [
				event [object!]
			][
;				unless find [move time] event/action [
;					PRINT "CORE GLASS HANDLER()"
;					print event/action
;				]
				;vprint ["event-window: " type? event/view-window]
				;vprint ["window title: " event/view-window/text]
				;vprint event/coordinates
				
				unless event/view-window [return event]
	
				; check if the event's face is managed by a !window viewport, 
				either viewport: get in event/view-window 'viewport [
					;vprint "This is a GLASS driven-window!"
					
					; this enables the viewport stream.
					; its also used to detect if the window is a VID or GLASS window
					event/viewport: event/view-window/viewport
					
					; uncomment for debugging 
					;unless event/action = 'time [probe event/action]
					switch/default event/action [
						move [
							; detect immobile mouse, to enable tool tips like system
							
							either event/coordinates = last-move-position [
								vprint "mouse is immobile!"
								
								either event/tick - immobile-start > 1000 [
									vprint "tooltip visible"
									unless tooltip-marble [
										event/action: 'show-tooltip
										tooltip-marble: true
										event
									]
								][
									; consume useless event!
									none
								]
							
							][
								; ignore this freakish event
								unless event/coordinates = 32767x32767 [
									last-move-position: event/coordinates
									immobile-start: event/tick
									event/action: 'pointer-move
									tooltip-marble: false
									event
								]
								; add delta coordinates for easier handling of relative mouse moves
								if last-down-event [
									event: make event [
										drag-delta: (event/coordinates - last-down-event/coordinates)
										drag-start: last-down-event/coordinates
									]
								]
								event
							]
						]
						active [
							vprint ["GLASS WINDOW ACTIVATED: " event/view-window/text]
							none
						]
						inactive [
							vprint ["GLASS WINDOW DE-ACTIVATED: " event/view-window/text]
							none
						]
						offset [
							event/action: 'window-position
							event
						]
						
						time [
							;prin [".  " event/tick ":" event/viewport/next-refresh]
							;vprint "REFRESH?"
							either all [
								event/tick > event/viewport/next-refresh
								any [
									event/viewport/glob/dirty?
									all [object? event/viewport/overlay event/viewport/overlay/dirty?]
								]
							][
								event/action: 'REFRESH
								event/viewport/next-refresh: event/tick + event/viewport/refresh-interval
								event
							][
								; timer isn't used ... don't stream further than this.
								none
							]
						]
						
						; there is no point in forcing CTRL+scroll to be scroll-page.
						; individual marbles should decide that for themselves. 
						;
						; this is why we merge these two events into a single event.
						;
						; just check if CTRL is pressed anyways.
						;
						; this event will usually be consumed by windows, changed to 'SCROLL set the marble
						; and be requeued so we can generate focused-scroll variant.
						scroll-line scroll-page [
							;vprint "SCROLLING!"
							
							event: make event [
								action: 'SCROLL-LINE
								amount: absolute coordinates/y
								direction: either coordinates/y > 0 [
									'pull
								][
									'push
								]
								coordinates: last-move-position ; we need to know WHERE the scrolling occured.
							]
							
							event
						]
						
						scroll [
							; we check if scrolled marble is focused or not
							if event/marble [
								if find focused-marbles event/marble [
									event/action: 'FOCUSED-SCROLL
								]
							]
							event
						]
						
						focus [
							;print "--------------FOCUS--------------"
							if event/marble [
								;vprint "MARBLE"
								either event/control? [
									;vprobe "control pressed!"
									unless find focused-marbles event/marble [
										append focused-marbles event/marble
									]
								][
									;vprint "NO CTRL"
									; unfocus everything
									foreach item focused-marbles [
										;vprint "UNFOCUSSING A MARBLE"
										queue-event clone-event/with event [action: 'unfocus marble: item]
									]
									append focused-marbles event/marble
									;vprint "ADDED FOCUSED MARBLE"
								]
							]
							event
						]
						
						unfocus [
							either event/marble [
								if marble: find focused-marbles event/marble [
									remove marble
								]
								event
							][
								; unfocus everything
								foreach item focused-marbles [
									queue-event clone-event/with event [action: 'unfocus marble: item]
								]
								none
							]
						]
						
						
						
						text-entry [
							; convert common key combinations into commands.
							compound-key-code: any [
								all [ event/control? event/shift? compound-key-code: join "ctrl+shift+" event/key ]
								all [ event/shift? join "shift+" event/key]
								all [ event/control? join "ctrl+" event/key]
							]
							
							event/key: any [select character-map-table compound-key-code select character-map-table event/key event/key]
							
							
							; this is a special event, which bypases normal dispatching!!
							foreach marble focused-marbles [
								event/marble: marble
								foreach handler marble/stream [
									handler event
								]
							]
							none
						]
						
						; special case... same as text-entry, but sends it back to marble which initiated it,
						; it doesn't use the focus list.
						;
						; note that event MUST have a marble associated to it.
						;
						; also note that the window will see the event, when it won't see normal text-entry events.
						marble-text-entry [
							; convert common key combinations into commands.
							compound-key-code: any [
								all [ event/control? event/shift? compound-key-code: join "ctrl+shift+" event/key ]
								all [ event/shift? join "shift+" event/key]
								all [ event/control? join "ctrl+" event/key]
							]
							
							event/key: any [select character-map-table compound-key-code select character-map-table event/key event/key]
;							; this is a special event, which bypases normal dispatching!!
;							foreach marble focused-marbles [
;								event/marble: marble
;								foreach handler marble/stream [
;									handler event
;								]
;							]
							event
						]
						
						resize [
							vprint "window resize!"
							; fix coordinates of resize
							; the resizing mechanism is REALLY screwed-up in view
							; its very easy to create an endless feedback loop.
							event/coordinates: event/viewport/view-face/size
							event/action: 'window-resized
							event
						]
						
						close [
							event/action: 'close-window
							event
						]
						
						down [
							vprint "MOUSE DOWN"
							; add the fast-click counter to all down-based events
							event: make event [fast-clicks: none]
							
							; remember, IF return none on failure
							fast-clicks?: if last-click + fast-click-delay > event/tick [
								event/fast-clicks: 1 + any [fast-clicks? 0]
							]
							
							event/action: 'pointer-press
							
							last-click: event/tick
							last-down-event: event
							
							event
						]
						
						up [
							vprint "MOUSE UP"
							
							event/action: 'pointer-release
							; add delta on release.
							if last-down-event [
								event: make event [
									drag-delta: (event/coordinates - last-down-event/coordinates)
									drag-start: last-down-event/coordinates
								]
								last-down-event: none
							]
							event
						]
						
						key [
							either all [
								event/control?
								find hot-keys event/key 
							][
								event/action: 'hot-key
								print "@@@"
							][
								; basic text entry events, but other events.
								event/action: 'text-entry
							]
							queue-event event
							none
						]
					
					][
						vprint ["CORE unhandled: " event/action]
						event
					]
					
				][
					vprint "CORE HANDLER: NO WINDOW IN EVENT"
					event
				]
			]
		]
	]
	;ask "DEFAULT HANDLERS ADDED"

]
	

	


	


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %event.r 
    date: 4-Aug-2010 
    version: 1.0.6 
    slim-name: 'event 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: EVENT
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: FRAME  v0.8.0
;--------------------------------------------------------------------------------

append slim/linked-libs 'frame
append/only slim/linked-libs [


;--------
;-   MODULE CODE


;- slim/register/header
slim/register/header [

	; declare words so they stay bound locally to this module
	!plug: liquify*: !glob: content*: fill*: link*: unlink*: detach*: none
	
	; sillica lib
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: none
	prim-bevel: prim-x: prim-label: none
	include: none

	layout*: get in system/words 'layout
	
	

	;- LIBS
	glob-lib: slim/open/expose 'glob none [!glob]
	liquid-lib: slim/open/expose 'liquid none [
		!plug 
		[liquify* liquify ] 
		[content* content] 
		[fill* fill] 
		[link* link] 
		[unlink* unlink] 
		[detach* detach] 
	]
	sillica-lib: slim/open/expose 'sillica none [
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		prim-bevel
		prim-x
		prim-label
	]
	epoxy-lib: slim/open/expose 'epoxy none [!box-intersection]

	
	marble-lib: slim/open 'marble none
	

	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;

	
	
	;--------------------------------------------------------
	;-   
	;- !FRAME[ ]
	!frame: make marble-lib/!marble [
	
		;-    aspects[ ]
		aspects: context [
			; managed positioning
			;-        offset:
			;
			; when set to -1x-1, the offset will be manipulated by the default fasten code.
			offset: -1x-1
			
			;-        color
			color: none ;theme-bg-color
			
			
			;-        frame-color
			frame-color: theme-border-color
			
			
			;-        disable?:
			; this will dim the gui and add an input blocker OVER our collection.
			disable?: false
			
			;-        corner:
			corner: 3
			
		]
		
		
		;-    material[ ]
		material: make material [
	
			;-        position:
			; the global coordinates your marble is at 
			; (automatically linked to gui by parent frame).
			position: 0x0 
			
			
			;-        border-size:
			;
			; border-size is used as a containter for now, but eventually, it will be a calculated value,
			; based on margins, padding and edge-size
			border-size: 5x5
			
			
			;-        content-size:
			; depending on marble type, the content-size will mutate into different sizing plugs
			; the most prevalent is the !text-sizing type which expects a !theme plug
			;content-size: none
			
			

			;-        fill-weight:
			; fill up / compress extra space in either direction (independent), but don't initiate resising
			;
			; frames inherit & accumulate these values, marbles supply them.
			fill-weight: 0x0
			
			
			;-        fill-accumulation:
			; stores the accumulated fill-weight of this and previous marbles.
			;
			; allows you to identify the fill regions
			;
			;	regions  0  2 3   6  6  8
			;	fill      2  1  3  0  2
			;	gui      |--|-|---|..|--|
			;
			; using regions fills all gaps and any decimal rounding errors are alleviated.
			fill-accumulation: 0x0
			
			
			
			;-        stretch:
			; marble benefits from extra space, initiates resizing ... preempts fill
			;
			;
			; frames inherit & accumulate these values, marbles supply them.
			stretch: 0x0
			
					
			;-        dimension:
			; computed size, setup by parent frame, includes at least min-dimension, but can be larger, depending
			; on the layout method of your parent.
			;
			; dimension is a special plug in that it is allocated arbitrarily by the marble as a !plug,
			; but its valve, will be mutated into what is required by the frame.
			;
			; the observer connections will remain intact, but its subordinates are controled
			; by the frame on collect.
			dimension: 200x300
			
			
			;-        min-dimension:
			;
			; minimal space required by this frame including any layout properties like margins,
			; borders, padding, frame banner, required size and accumulated minimum sizes of collection.
			;
			; used by dimension
			min-dimension: 30x30
			
			
			;-        content-dimension:
			; same as dimension with our own added size requirements removed (borders, margins, etc)
			content-dimension: none
			
			;-        content-min-dimension:
			; same as min-dimension without our own added size requirements removed (borders, margins, etc)
			content-min-dimension: none
			
			
			;-        content-spacing:
			; accumulates all the offsets in our collection
			content-spacing: none
			
			
			
			
			;-        origin:
			; this is the origin we supply to our children
			; the clip-region might also use this value or the position.
			;
			; normally, the origin is connected to border-size and offset
			origin: 5x5
			
			
			;-        clip-region
			; our own calculated global cliping rectangle, is affected by parent frame clip regions once collected.
			; until a marble is collected, its clipping region makes it invisible (from -1x-1 to -1x-1)
			clip-region: none
			
			
			;-        parent-clip-region:
			parent-clip-region: none
			
		]
		

		;-    collection:
		; stores any marbles we contain (link to?)
		; ATTENTION:  ONLY use the collect() & to manipulate this list.
		collection: none
		
		
		;-    frame-bg-glob:
		; a glob used to render any frame visuals behind marbles.
		; intersects our clip region with that of our frame.
		;
		; this allows glass to simulate view's hierarchical nested face clipping using draw !!!
		frame-bg-glob: none

		;-    frame-fg-glob:
		; a glob used to render any frame visuals Over its marbles.
		; the default frame uses this to restore its frame's clip region.
		frame-fg-glob: none


		;-    spacing-on-collect:
		; when collecting marbles, automatically set their offset to this value
		spacing-on-collect: 5x5
		
		
		
		;-    layout-method:
		; this changes the frame into various types of grouped layout methods.
		;
		; values are: [row, column, absolute, relative, column-grid, row-grid, explode]
		;
		; changing this value at run-time should only be performed by expert programmers
		; since it requires rebuilding outer panes to adjust to new inner values.
		;
		; if the method changes and is incompatible with the previous method, some layout 
		; breakage will result in outer panes, since the various calculated sizing parameters
		; will not be updated for them.
		;
		; usually, this means calling refresh on the most outer frame which can be affected by
		; the change to this frame.
		; 
		layout-method: 'column
		
		
		;-    valve []
		valve: make valve [

			type: '!marble


			;-        style-name:
			style-name: 'frame
		

			;-        is-frame?:
			is-frame?: true


			;-        glob-class:
			; defines the glob which will be built by each marble instance.
			glob-class: none
			

			;-        bg-glob-class:
			; class used to allocate and link a glob drawn BEHIND the marble collection
			bg-glob-class: make !glob [
				valve: make valve [
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup  these will be stored within the instance under input
						position !pair (random 200x200)
						dimension !pair (300x300)
						color !color
						frame-color  !color (random white)
						corner !integer
						; uncomment to debug
;						clip-region !block ([0x0 1000x1000])
;						min-dimension !pair
;						content-dimension !pair
;						content-min-dimension !pair
					]
					
					;-            glob/gel-spec:
					gel-spec: [
						; event backplane
						none
						[]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						
						; FG LAYER
						position dimension color frame-color corner
						;------
						; uncomment following for debugging
						;
						;   min-dimension content-dimension content-min-dimension
						;------
						[
							; here we restore our parent's clip region  :-)
							;clip (data/parent-clip-region=)
							
							fill-pen (data/color=)
							pen (data/frame-color=)
							line-width 1
							box (data/position=) (data/position= + data/dimension= - 1x1) (data/corner=)
							;------
							; uncomment for debugging purposes.
							;	line-width 1
							;	pen blue 
							;	fill-pen (0.0.0.129 + data/color=)
							;	box (data/position=) (data/position= + data/content-dimension=)
							;	pen red 
							;	fill-pen (0.0.0.129 + data/color=)
							;	box (data/position=) (data/position= + data/dimension=)
							;	pen black 
							;	fill-pen (0.0.0.129 + data/color=)
							;	box (data/position=) (data/position= + data/min-dimension=)
							;	pen white 
							;	fill-pen (0.0.0.129 + data/color=)
							;	box (data/position=) (data/position= + data/content-min-dimension=)
							;------
						
						]
						
						
						; controls layer
						;[]
						
						
						; overlay 
						;[]
					]
				]
			]
			

			;-        fg-glob-class:
			; class used to allocate and link a glob drawn IN FRONT OF the marble collection
			;
			; windows use this to create an input blocker, for example.
			fg-glob-class: make !glob [
				valve: make valve [
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup  these will be stored within the instance under input
						position !pair (random 200x200)
						dimension !pair (300x300)
						disable? !bool
						;color !color
						;frame-color  !color (random white)
						;clip-region !block ([0x0 1000x1000])
						;parent-clip-region !block ([0x0 1000x1000])
					]
					
					;-            glob/gel-spec:
					gel-spec: [
						; event backplane
						disable? position dimension
						[
							(either data/disable?= [
								compose [
									pen none
									fill-pen (white) ; erases backplane.
									box  (data/position=) (data/position= + data/dimension= - 1x1)
								]
								][[]]
							)
						]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						; position dimension color frame-color clip-region parent-clip-region
						disable? position dimension
						[
							; here we restore our parent's clip region  :-)
							;clip (data/parent-clip-region=)
							
							(
								either data/disable?= [
									compose [
										pen none
										fill-pen (theme-bg-color + 0.0.0.100)
										box  (data/position=) (data/position= + data/dimension= )
									]
								][
									[]
								]
							)
							
							;pen (data/color=) red
							;line-pattern 10 10
							;box (vprint ["CLIP REGION:" mold data/clip-region= ] data/clip-region= )
							;(prim-bevel data/position= data/dimension=  white * .75 0.2 3)
							;(prim-X data/position= data/dimension=  (data/color= * 1.1) 10)
			
						]
						
						; controls layer
						;[]
						
						
						; overlay 
						;[]
					]
				]
			]

		
			;-----------------
			;-        gl-materialize()
			;
			; see !marble for details
			;-----------------
			gl-materialize: func [
				frame [object!]
			][
				vin [{glass/!} uppercase to-string frame/valve/style-name {[} frame/sid {]/gl-materialize()}]
				; manage relative positioning
				;if relative-marble? frame [
					frame/material/position: liquify*/fill epoxy-lib/!junction frame/material/position
					;link* frame/material/position frame/aspects/offset
				;]

				frame/material/origin: liquify*/fill !plug frame/material/origin
				frame/material/dimension: liquify*/fill !plug frame/material/dimension
				frame/material/content-dimension: liquify*/fill !plug frame/material/content-dimension
				frame/material/min-dimension: liquify*/fill !plug frame/material/min-dimension
				frame/material/content-min-dimension: liquify*/fill !plug frame/material/content-min-dimension
				
				
				; manage resizing
				frame/material/fill-weight: liquify*/fill !plug frame/material/fill-weight
				frame/material/fill-accumulation: liquify*/fill !plug frame/material/fill-accumulation
				frame/material/stretch: liquify*/fill !plug frame/material/stretch
				frame/material/content-spacing: liquify*/fill !plug 0x0
				frame/material/border-size: liquify*/fill !plug frame/material/border-size
				
				; this controls where our PARENT can draw we link to it, cause we restore it after our marbles 
				; have done their stuff.   We also need it to resolve our own clip-region
				; 
				; clip regions are stored as a block containing two pairs
				;marble/parent-clip-region: liquify* !plug
				
				
				; this controls where WE can draw
				frame/material/clip-region: liquify* epoxy-lib/!box-intersection
				;link* frame/material/clip-region frame/material/position
				;link* frame/material/clip-region frame/material/dimension
				
				frame/material/parent-clip-region: liquify* !plug 
				
				; our link itself after.
				;marble/material/origin: liquify*/link epoxy/!fast-add marble/material/position
				


				
				; this is meant for styles to setup their specific materials.
				;marble/valve/setup-materials marble
				
				vout
			]
			
			
			
			

			
			;-----------------
			;-        accumulate()
			;
			; add one or more marble(s) in our collection
			;
			; this is just a wrapper which accepts several input types.
			;
			; it is optimised for collecting several marbles at once.
			;
			; when actively controling marbles, use GL-COLLECT() directly.
			;
			;-----------------
			accumulate: func [
				frame [object!]
				marbles [object! block!]
				/local marble fg-glob
			][
				vin [{glass/!} uppercase to-string frame/valve/style-name {[} frame/sid {]/accumulate()}]
				; normalize the input type,
				; if marbles is a block, it must only contain a series of marble OBJECTS.
				marbles: compose [(marbles)]
				
				vprint [length? marbles " Marble(s) to collect"]
				
				if object? frame/frame-fg-glob [
					vprint "must unlink FG GLOB"
					fg-glob: frame/frame-fg-glob
					frame/frame-fg-glob: none
					frame/glob/valve/unlink/only frame/glob fg-glob
				]
				
				; collect every marble
				foreach marble marbles [
					frame/valve/gl-collect frame marble
				]
				
				;ask ""
				
				if object? fg-glob [
					vprint "Relinking FG GLOB"
					frame/frame-fg-glob: fg-glob
					fg-glob: none
					frame/glob/valve/link frame/glob frame/frame-fg-glob
				]
				
				;----
				; cleanup GC
				marble: marbles: frame: fb-glob: none
				
				vout
			]
			
			;-----------------
			;-        link-glob()
			; callback used to perform the link of a collected marble.
			;
			; in some styles, collected marbles aren't directly linked to the frame's 
			; glob, but to an intermediate.
			;-----------------
			link-glob: func [
				frame
				marble
			][
				vin [{link-glob()}]
				frame/glob/valve/link frame/glob marble/glob
				vout
			]
			
			
			;-----------------
			;-        unlink-glob()
			; callback used to perform the unlink of a discarded marble.
			;
			; in some styles, collected marbles aren't directly linked to the frame's 
			; glob, but to an intermediate.
			;-----------------
			unlink-glob: func [
				frame
				marble
			][
				vin [{unlink-glob()}]
				frame/glob/valve/unlink/only frame/glob marble/glob
				vout
			]
			
			

			
			;-----------------
			;-        gl-collect()
			;
			; add a marble to a frame.
			;
			; use accumulate() when collecting several marbles at a time
			;
			; it is THE ONLY LEGAL WAY to assign marbles to a frame.
			;
			; ATTENTION: collecting a marble which is already in a frame, automatically 
			; removes it from that frame.
			;
			; <TO DO> refinements: 
			;   /at index [integer! object!]  ; same as /before when used with object!
			;   /before marble [object!]
			;   /after marble [object!]
			;-----------------
			gl-collect: func [
				frame [object!]
				marble [object!]
				/top "collects at the top rather tahn the end"
				/local frm
			][
				vin [{glass/!} uppercase to-string frame/valve/style-name {[} frame/sid {]/gl-collect()}]
				vprint ["collecting one marble of type: " to-string marble/valve/style-name ]
				
				
				either frm: get in frame 'collect-in-frame [
					marble/frame: frm
					frm/valve/gl-collect frm marble
				][
					; make sure we add marbles UNDER frame's fg-glob
					if object? frame/frame-fg-glob [
						;print "must unlink FG GLOB"
						frame/glob/valve/unlink/only frame/glob frame/frame-fg-glob
					]
					
					; make sure the marble isn't shared in several frames
					if any [
						; marble is framed, but its from another collection
						all [
							not same? marble/frame frame
							marble/frame
						]
						all [
							; on init, the frame is set, but its not yet collected, ignore the discard in this case.
							same? frame marble/frame
							find frame/collection marble
						]
					][
						; note:  gl-discard() calls discard() on its own
						marble/frame/valve/gl-discard marble/frame marble
					]
	
	
					
					; assign this frame to the marble
					marble/frame: frame
					
					; hoard it in our collection
					either top [
						insert frame/collection marble
					][
						append frame/collection marble
					]
					
					; tell our glob to add the marble's graphics to our graphics.
					link-glob frame marble
					
	
	
	
					; make sure fg-glob is ALWAYS in front of marbles
					if object? frame/frame-fg-glob [
						;print "Relinking FG GLOB"
						frame/glob/valve/link frame/glob frame/frame-fg-glob
					]
	
					
					; rarely, if ever, used... but may be usefull for specialized layout styles
					; this is advanced stuff, use with caution.	
					frame/valve/collect frame marble
				]
				vout
			]
			
			
			;-----------------
			;-        collect()
			;
			; this is a style-specific collection method for custom styles.
			;
			; it is evaluated WITHIN the low-level internal gl-collect() call, AFTER gl-collect has completed.
			;
			; this is not intended for casual users, there are many things to know when collecting a marble,
			; and full understanding of the framework is required.
			;
			; nonetheless, advanced users will enjoy the fact that they can actually change how marbles
			; are stacked visually, so there is virtually no limit beyond what Draw can accomplish.
			;-----------------
			collect: func [
				frame
				marble
			][
				vin [{glass/!} uppercase to-string frame/valve/style-name {[} frame/sid {]/collect()}]

				vout
			]
			
			
			

			;-----------------
			;-        gl-discard()
			;
			; remove one or more marble(s) from OUR collection
			;
			; the only valid word marble value is 'all ('last , 'first are obvious enhancements)
			;
			; note that this doesn't destroy the marbles, it just removes it/them from our collection.
			;
			; ATTENTION: care must be taken to supply only marbles which actually are part of the frame's collection
			;            otherwise an error WILL BE RAISED!
			;-----------------
			gl-discard: func [
				frame [object!]
				marble [object! block! word!]
				/local marbles blk frm
			][
				vin [{glass/!} uppercase to-string frame/valve/style-name {[} frame/sid {]/gl-discard()}]
				
				either frm: get in frame 'collect-in-frame [
					frm/valve/gl-discard frm marble
				][
					; normalize the input type
					switch type?/word marble [
						word! [
							if marble = 'all [
								vprint "Discarding ALL marbles"
								marbles: copy frame/collection
							]
						]
						object! [
							marbles: reduce [marble]
						]
						block! [
							marbles: marble
						]
					]
					
					
					vprint ["number of marbles: " length? marbles]
					
					foreach marble marbles [
						vprint "-"
						vprobe type? :marble
					]
					
					
					foreach marble marbles [
						vprint "--------------------"
						vprint ["type? marble: " type? marble]
						vprint ["marble:       " marble/sid]
						vprint ["marble/frame: " all [marble/frame marble/frame/sid]]
						
						either blk: find frame/collection marble [
						
							; first discard a style's collection customisation
							frame/valve/discard frame marble
							
							; remove marble from collection
							remove blk
	
							; disconnect the marble position from its frame
							if relative-marble? marble [
								if object? get in marble/material 'position [
									if 2 = length? marble/material/position/subordinates [
										marble/material/position/valve/unlink/tail marble/material/position
									]
								]
							]
							
							; disconnect the marble's glob from its frame
							unlink-glob frame marble
							
							; detach marble from frame
							marble/frame: none
							
							
						][
							to-error "Trying to discard marble from wrong frame"
						]
	
						vprint "!!!"
					]
				]
				vout
			]
			
			
			
			
			
			
			;-----------------
			;-        discard()
			;
			; a style should undo any special stuff it might do when it collect collected
			;-----------------
			discard: func [
				frame
				marble
			][
				vin [{glass/!} uppercase to-string frame/valve/style-name {[} frame/sid {]/discard-hook()}]
				
				vout
			]
			
			
						
			
			
			;-----------------
			;-        gl-fasten()
			;
			; low-level default GLASS fastening.
			;
			; perform all linkeage required for this frame to effectively layout its collection.
			;
			; this is usually only called once, when our collection has changed.  since we must update
			; how each marble is related to its siblings and how we compare to the whole collection's new
			; content.
			;
			; the frame is responsable for allocation and linking marbles so the layout will
			; correspond to the frame's intended layout look and feel.
			;
			; Fasten is where MUTATIONS will take place on materials, so do not expect any specific
			; marble to retain its previous marble/valve after gl-fasten is called.
			;
			; the frame will always call fasten on its marble collection members BEFORE it performs its own
			; fastening on the marbles.
			;
			; note, fasten() on a marble is ONLY called from frames ... control-type
			; marbles never call gl-fasten() directly !!
			;
			;
			; Note, right now, gl-fasten isn't optimised for speed but raw robustness... so for this reason,
			; each fasten call, unlinks the whole collection and refastens it from scratch.  this way we are
			; sure that strange collect() calls do not corrupt the display by adding a new marble somewhere
			; in the middle of the collection.
			;
			; Once glass will mature and usage patterns become obvious, we will improve gl-fasten(). 
			;
			; at least, gl-fasten is called when the whole collection is accumulated, not everytime a single 
			; marble is collected
			;-----------------
			gl-fasten: func [
				frame
				;/wrapper "fasten this frame as well"
				/local marble previous-marble mtrl mmtrl
			][
				vin [{glass/!} uppercase to-string frame/valve/style-name {[} frame/sid {]/gl-fasten()}]
				
				mtrl: frame/material
				
				;-            -wrapper
				if find frame/options 'wrapper [
					vprint "SPECIFYING WRAPPER!"
					vprint content* frame/aspects/offset
					link*/reset mtrl/position frame/aspects/offset
					
				]


				; setup our own materials				
				link*/reset mtrl/origin reduce [
					mtrl/position 
					mtrl/border-size
				]
				link*/reset mtrl/content-dimension reduce [
					mtrl/dimension
					mtrl/border-size
					mtrl/border-size
				]
				
				link*/reset mtrl/min-dimension reduce [
					mtrl/content-min-dimension
					mtrl/border-size
					mtrl/border-size
				]

				
				
				
				
				;-           -mutate
				; mutate our materials
				mtrl/origin/valve: epoxy-lib/!pair-add/valve
				mtrl/content-dimension/valve: epoxy-lib/!pair-subtract/valve
				mtrl/min-dimension/valve: epoxy-lib/!pair-add/valve
				;vprint ["content-dimension: " content* mtrl/content-dimension ]

				
				switch frame/layout-method [
					column [
						vprint "COLUMN!"
						; position
						mtrl/content-min-dimension/valve: epoxy-lib/!vertical-accumulate/valve
						mtrl/fill-weight/valve: epoxy-lib/!vertical-accumulate/valve
						mtrl/content-spacing/valve: epoxy-lib/!vertical-accumulate/valve
					]
					
					; 
					row [
						vprint "ROW!"
						; position
						mtrl/content-min-dimension/valve: epoxy-lib/!horizontal-accumulate/valve
						mtrl/fill-weight/valve: epoxy-lib/!horizontal-accumulate/valve
						mtrl/content-spacing/valve: epoxy-lib/!horizontal-accumulate/valve
					]
				]


				
				; setup my clip-region
				
				; link to my parent's clip-region
				
				
				;-            -reset frame
				
				; reset our marble-dependent material properties
				unlink*/detach mtrl/fill-weight
				unlink*/detach mtrl/stretch
				unlink*/detach mtrl/content-spacing
				
				link*/reset mtrl/content-min-dimension mtrl/content-spacing

				
				previous-marble: none
				
				; manage collection
				;-               -collection
				foreach marble frame/collection [
					mmtrl: marble/material
					either previous-marble [
						; offset relative to previous marble
						link*/reset mmtrl/position previous-marble/material/position
						link* mmtrl/position previous-marble/material/dimension
						link* mmtrl/position marble/aspects/offset
						
						; accumulate fill weight
						link*/reset mmtrl/fill-accumulation  mmtrl/fill-weight
						link* mmtrl/fill-accumulation  previous-marble/material/fill-accumulation
						
						either frame/spacing-on-collect [
							;if -1x-1 = content* marble/aspects/offset  [
								fill* marble/aspects/offset frame/spacing-on-collect
							;]
						][
							;if -1x-1 =  content* marble/aspects/offset  [
								fill* marble/aspects/offset 0x0
							;]
						]
						
					][
						if frame/spacing-on-collect [
							;unless content* marble/aspects/offset  [
								;first item is at 0x0 by default
								fill* marble/aspects/offset 0x0
							;]
						]

						; offset relative to frame
						link*/reset mmtrl/position mtrl/origin
						link* mmtrl/position marble/aspects/offset
						
						; set fill weight
						link*/reset mmtrl/fill-accumulation  mmtrl/fill-weight
					]
					
					; accumulate all content.
					link* mtrl/content-min-dimension mmtrl/min-dimension
					
					link* mtrl/content-spacing marble/aspects/offset
					
					
					;-               -sizing
					;
					; traditional GLASS resizing algorithm implemented using dataflow!
					; connect dimension to requirements.
					link*/reset mmtrl/dimension reduce [
						mtrl/content-dimension
						mtrl/content-min-dimension
						mtrl/fill-weight
						mmtrl/min-dimension
						mmtrl/fill-weight
						mmtrl/fill-accumulation
						mtrl/content-spacing
					]
					
					
					
					
					
					; accumulate frame fill weight
					link* mtrl/fill-weight mmtrl/fill-weight
					
					
					;-------
					; take care of collection MUTATIONS
					mmtrl/fill-accumulation/valve: epoxy-lib/!pair-add/valve
					
					
					switch frame/layout-method [
						column [
							vprint "COLUMN!"
							; position
							mmtrl/position/valve: epoxy-lib/!vertical-shift/valve
							mmtrl/dimension/valve: epoxy-lib/!vertical-fill-dimension/valve
						]
						
						; 
						row [
							vprint "ROW!"
							; position
							mmtrl/position/valve: epoxy-lib/!horizontal-shift/valve
							mmtrl/dimension/valve: epoxy-lib/!horizontal-fill-dimension/valve
						]
					]
					
					
					previous-marble: marble
				]
				
				
				;------
				; frame inner-fastening
				if find frame/options 'wrapper [
					vprint "this is a wrapper"
					; wrappers are simple dimension containers
					mtrl/dimension/valve: !plug/valve
					
					; provide a usefull default wrapper dimension
					; if size is later filled manually this link is ignored as usual by liquid .
					link*/reset mtrl/dimension mtrl/min-dimension
					;probe content* frame/material/min-dimension
					;probe content* frame/material/dimension
					;ask "!!!"
				]

				
;				link* marble/material/position marble/aspects/offset
;
;				if all [
;					in marble/material 'clip-region
;					object? marble/material/clip-region
;				][
;					;do-liquid-cycle-debug: true
;					;vprint "LINK MARBLE TO PARENT FRAME CLIP RECT"
;					link* marble/material/clip-region frame/material/clip-region
;				]
;				if all [
;					in marble/material 'parent-clip-region
;					object? marble/material/parent-clip-region
;				][
;					;do-liquid-cycle-debug: true
;					;vprint "LINK MARBLE TO PARENT FRAME CLIP RECT"
;					link* marble/material/parent-clip-region frame/material/clip-region
;				]
;
;				;-----------------------------
;
;
;
;				either marble/valve/is-frame? [
;					link* marble/material/origin frame/material/position
;				
;				
;				
;				][
;					unlink* marble/position
;
;
;				]
;
;			
;
;				; just optimisation of relative positioning (retrieve our position once, for all marbles)
;				; get our own position (anywhere it is)
;				;plug: get-aspect/or-material/plug frame 'position
;				
;				;--
;				; if the inner marble is expecting to be relatively positioned, then link its position 
;				; to our position.
;				;
;				; ATTENTION:  we do not use /reset on the link, since the marble is already linked to 
;				; its offset.  if the position was FILLED (piped or container) then this value
;				; will not be used since the marble/position/valve/process() is not being called.
;				; 
;				
;				 
;				;                MANAGE LAYOUT
;				if relative-marble? marble [
;				
;					set
;				
;					;link* marble/material/position frame/material/position 
;					;link* marble/material/origin frame/aspect/offset
;					
;					l: last frame/collection
;					f: first frame/collection
;					;either same? l f [
;						; (depending on the index of the marble, we mutate the plug into different types.
;						; MUTATE THE POSITION INTO AN EPOXY/VERTICAL-SHIFT!
;					;	either same? marble/
;						marble/material/position/valve: epoxy-lib/!vertical-shift/valve
;						
;						unlink marble/material/position 
;						link* marble/material/position frame/material/origin
;					
;				]
				
				

				
				; perform any style-related fastening.
				frame/valve/fasten frame
				vout
			]
			
			
						
			;-----------------
			;-        fasten()
			;
			; style-oriented public fasten call.  called at the end of (within) gl-fasten()
			;
			; CURRENTLY NOT ENABLED  !!!
			;-----------------
			fasten: func [
				frame
			][
				vin [{glass/!} uppercase to-string frame/valve/style-name {[} frame/sid {]/fasten()}]
				
				vout
			]
			

			

			;-----------------
			;-        specify()
			;
			; parse a specification block during initial layout operation
			;
			; frames create new marble instances at specify time.
			; they are also responsible for calling layout setup operations providing any
			; environment which is required by new marbles
			;-----------------
			specify: func [
				frame [object!]
				spec [block!]
				stylesheet [block! none!] "required so stylesheet propagates in marbles we create"
				;/wrapper "this is a wrapper, call gl-fasten() accordingly"
				/local marble item pane data marbles set-word pair-count tuple-count
			][
				vin [{glass/!} uppercase to-string frame/valve/style-name {[} frame/sid {]/specify()}]
				;v?? spec
				
				stylesheet: any [stylesheet master-stylesheet]
				pair-count: 1
				tuple-count: 1
				
				parse spec [
					any [
						copy data ['with block!] (
							;print "SPECIFIED A WITH BLOCK"
							;frame: make frame data/2
							;liquid-lib/reindex-plug frame
							
							do bind/copy data/2 frame 
							
							
							;probe marble/actions
							;ask ""
						) | 
						'corner set data integer! (
								fill* frame/aspects/corner data
						) |
						'tight (
							frame/spacing-on-collect: 0x0
							if block? frame/collection [
								foreach marble frame/collection [
									fill* marble/aspects/offset 0x0
								]
							]
							;fill* frame/aspects/frame-color red
							fill* frame/material/border-size 0x0
						) |
						set data tuple! (
							switch tuple-count [
								1 [
									vprint "frame COLOR!" 
									vprint data
									fill* frame/aspects/frame-color data
								]
								
								2 [
									fill* frame/aspects/color data
								]
							]
							tuple-count: tuple-count + 1
						) |
						set data pair! (
							switch pair-count [
								1 [  
									vprint "frame Border-size!" 
									fill* frame/material/border-size data
								]
								
								2 [
									frame/spacing-on-collect: data
								]
							]
							pair-count: pair-count + 1
						
						) |
						set data block! (
							vprint "frame MARBLES!" 
							pane: regroup-specification data
							new-line/all pane true
							vprint "skipping inner pane attributes"
							pane: find pane block!
							
							if pane [
								
								; create & specify inner marbles
								foreach item pane [
									if set-word? set-word: pick item 1 [
										; store the word to set, then skip it.
										; after we use set on the returned marble.
										;print "SET WORD!"
										
										item: next item
									]
									either marble: alloc-marble/using first item next item stylesheet [
										marbles: any [marbles copy []]
										
										; set the frame, just so child gl-fasten, may use the frame to take
										; contextual decisions.
										append marbles marble
										marble/frame: frame
										
										marble/valve/gl-fasten marble
										
										if set-word? :set-word [
											set :set-word marble
										]
										
									][
										; because of specification's parsing, this code should never really be reached
										vprint ["ERROR creating new marble of type: " item " in frame!"]
									]
								]
								
								; add all children to our collection
								frame/valve/accumulate frame marbles
							]
							
							
							; take this frame and fasten it. (might be empty)
							; we remove this since it caused a double fastening of all frames!
							; it was instead added to the layout function directly.
							;frame/valve/gl-fasten frame
							
						) |
						skip 
					]
				]
				
				frame/valve/dialect frame spec stylesheet
				
				;------
				; cleanup GC
				marbles: spec: stylesheet: marble: pane: item: data: none
				vout
				frame
			]
		]
	]
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %frame.r 
    date: 20-Jun-2010 
    version: 0.8.0 
    slim-name: 'frame 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: FRAME
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: MARBLE  v0.5.4
;--------------------------------------------------------------------------------

append slim/linked-libs 'marble
append/only slim/linked-libs [


;--------
;-   MODULE CODE



;- slim/register/header
slim/register/header [

	
	
	;- LIBS
	to-color: none
	
	!glob: to-color: none
	glob-lib: slim/open/expose 'glob none [!glob to-color]
	
	
	!plug: liquify*: content*: fill*: link*: unlink*: none
	liquid-lib: slim/open/expose 'liquid none [!plug [liquify* liquify ] [content* content] [fill* fill] [link* link] [unlink* unlink]]
	
	
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: none
	prim-bevel: prim-x: prim-label: include: none
	
	sillica-lib: slim/open/expose 'sillica none [
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		prim-bevel
		prim-x
		prim-label
		include
	]
	epoxy-lib: slim/open/expose 'epoxy none [!box-intersection]
	
	event-lib: slim/open 'event none

	

	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;

	;--------------------------------------------------------
	;-   
	;- !MARBLE[ ]
	!marble: make !plug [
		;-    Aspects[ ]
		;
		; (public marble plugs)
		;
		; stores any controlable/dynamic aspect of a marble.
		;
		; each aspect becomes a liquid !plug
		;
		; you may link or pipe any of these at will within/to your application.
		;
		; they are automatically created at init, much like the globs within.
		; some glob inputs will link TO these, so be sure not to reallocate the plugs themselves.
		;
		; never store the aspects object directly, it can be replaced by the marble at any time.
		;
		; aspects include dynamic theme data like resizing and layout information... so don't poke here
		; unless you really know what you are doing.
		;
		; some of the aspects will be filled up by the layout algorythm, some might be setup by gl-specify() directly.
		aspects: context [
			;-       offset
			offset: -1x-1   ; this is the relative to parent coordinates your marble is at.

			;-       size:
			; this is the user controlable size of the marble, 
			; if size is none, minimum-dimension ignores it.
			; 
			; and automatically calculates a size instead, based on font and label.
			;
			; note that if size has a -1 component then only that orientation is automatically
			; calculated. (this allows you to scale one orientation based on the other's manually-set size)
			size: -1x-1 ;40x40

			;-       state:
			state: none

			;-       color:
			color: none
			
			;-       label-color:
			label-color: black
			
			;-       label:
			label: none
			
			;-       font:
			font: theme-base-font
			
			;-       align:
			align: 'center
			
			;-       hover?:
			hover?: none
			
			;-       padding:
			padding: 3x2
			
			
		]
		
		
		;-    Material[]
		;
		; (private marble plugs)
		;
		; stores processed aspects, which are usually linked directly by the glob and between each other.
		;
		; many material properties link to the public aspects as the basic data to manipulate for the 
		; marble's consumption. 
		;
		; materials are managed by the various levels of glass.  This is the general purpose container for 
		; any dynamic liquid linkage.
		;
		; this is where we do a lot of the layout calculation through frame's fasten() call.
		;
		; each marble has its own material instance.  Never store the material object itself directly elsewhere, 
		; it may be replaced by the marble at any time.  
		;
		; ALWAYS refer via marble/material
		;
		material: context [
			;-       position:
			; the global coordinates your marble is at 
			; (automatically linked to gui by parent frame).
			;
			; note that if your marble is within a pane, the position is relative
			; to ITS position MINUS any transformation it adds
			position: 0x0 
			
			
			;-       window-offset:
			; this is experimental, and used only rarely (usually within event
			; handlers.  it SHOULD NOT be used within GLOBs, cause we do not 
			; want double position calculation.
			;
			; each window-offset is linked to its frame in a way which allows
			; any marble to know its absolute window position.
			;
			; panes, resets the positioning because they use 0x0 as the origin
			; and use a translate to push the graphics within a face instead of 
			; recalculating the complete collection resizing.
			window-offset: none
			
			
			;-       fill-weight:
			; fill up / compress extra space in either direction (independent), but don't initiate resising
			;
			; frames inherit & accumulate these values, marbles supply them.
			;
			; some frames & groups might have overrides which actually allow you to make stiff frames.
			fill-weight: 1x0
			
			;-       fill-accumulation:
			; stores the accumulated fill-weight of this and previous marbles.
			;
			; allows you to identify the fill regions
			;
			;	regions  0  2 3   6  6  8
			;	fill      2  1  3  0  2
			;	gui      |--|-|---|..|--|
			;
			; using regions fills all gaps and any decimal rounding errors are alleviated.
			fill-accumulation: 0x0
			
			;-       stretch:
			; marble benefits from extra space, initiates resizing ... preempts fill
			;
			;
			; frames inherit & accumulate these values, marbles supply them.
			stretch: 0x0
			
			
			
			;-       content-size:
			; depending on marble type, the content-size will mutate into different sizing plugs
			; the most prevalent is the !text-sizing type which expects a !theme plug
			content-size: 0x0
			
			
			
			;-       min-dimension:
			; this is your internal calculated minimal dimension
			; it should include things like content, aspect's size, margins, padding, borders, etc.
			;
			; marbles usuall should allocate enough space to display data correctly,
			; frames will usually collect the minimum space required by its marble collection.
			;
			; frame uses this, but its each marble's responsability to set it up.
			min-dimension: 100x25
			
			
			
			;-       dimension:
			; computed size, setup by parent frame, includes at least, needs, but can be larger, depending
			; on the layout method of your parent.
			;
			; dimension is a special plug in that it is allocated arbitrarily by the marble as a !plug,
			; but its valve, will be mutated into what is required by the frame.
			;
			; because of this, the dimension's instance may NOT contain/rely on any special attributes in
			; its plug instance.
			;
			; the observer connections will remain intact, but its subordinates are controled
			; by the frame on collect.
			;
			; this is what should actually get used by the glob.
			dimension: 0x0
			
		]
		
		
		
		;-    Shader:
		;
		; the shader will be the point of reference which stores theme (look & style) information.
		;
		; this plug is special, in that its the result of linking up various !shader nodes.
		; 
		; within a marble, where !shaders are used, any change to the shader will be refreshed dynamically
		; by any and all marbles which share this information.
		;
		; theme data includes default parameters for just about any aspect of a gui you wish to normalize,
		; like bg color, fonts, etc.
		;
		; because things are linked, within the theme manager, you can share and refine the theme specifically
		; for any level of the gui's marble, so two different marbles, although using the same class, might be
		; linked to two different branches of the same theme... one with larger fonts, used by banners,
		; the other using the default text font.
		;
		; this removes the need to create special styles simply to differentiate looks.
		;
		;shader: none
			
		
		;-    glob:
		; stores the glob instance used to render this marble
		; this can be a gel or stack type glob.
		glob: none
		
		
		
		
		;-    frame:
		; to what frame is this marble attached, once allocated?
		;
		; collect-marble() refreshes this correctly (its used by the frame on marble creation).
		frame: none
		
		
		;-    options:
		; store options for this marble.  This is internal to a marble and should never be
		; played with manually.
		;
		; usually an option will be added as a result of processing the marble's dialect so
		; that some detail is re-evaluated properly later-on.
		; 
		; currently supports:
		;
		;    wrapper:  the marble is a wrapper, so frame layout doesn't expect a parent frame.
		options: none
		
		;-    user-data:
		; this is a handy way to link application specific data within the marble,
		; so that you can refer to the application from within the marble.
		;
		; dome dialects might help you fill this value directly from the spec.
		;
		; to access this data in callbacks and actions, you'll usually do:
		;   event/marble/user-data
		;
		user-data: none
		
		
		;-    user-id:
		; you may put any of [string! integer! issue! word! tuple!] here, which will be used to refer to your
		; marble by name.
		;
		; the name need not be unique in a layout.  this is usefull to extract sets
		; of controls.
		;
		; some glass functions use this to browse a layout hierarchy 
		; and perform various operations on matching marbles.
		user-id: none
		
		
		
		;-    stream:
		; block of functions which are called on events.
		;
		; a stream is only allocated if you call add-handler on a marble.
		;
		; the marble dialect may do this for you.
		;
		; note: the api for streams is contained in the event.r module
		stream: none
		
		
		
		;-    actions[]
		actions: context [
;			;-----------------
;			;-        select()
;			;-----------------
;			select: func [
;				event
;			][
;				vin [{button/select()}]
;				vprint join content* event/marble/aspects/label " pressed" 
;				
;				vprobe event/marble/actions
;				
;				vout
;			]
;			
;			;-----------------
;			;-        release()
;			;-----------------
;			release: func [
;				event
;			][
;				vin [{button/release()}]
;				vprint join content* event/marble/aspects/label " clicked" 
;				vout
;			]
		]

		
		
		;-    valve[ ]
		valve: make valve [
		
			type: '!marble
		
			;-        style-name:
			; used as a label for debugging and node browsing.
			style-name: 'marble  
			
			
			;-        is-frame?:
			; separates between the two main marble types:
			;   controls:
			;     controls are the things you interact with within a gui.
			;
			;  frames:
			;     frames are used to create and manage the layout in general.
			;     most of what is true for a control is also true for a frame.
			is-frame?: false
			

			;-        is-viewport?:
			is-viewport?: false
			
			
			;-        glob-class:
			; defines the glob which will be built by each marble instance.
			;   glob-class/marble  is added automatically by setup.
			glob-class: make !glob [
				valve: make valve [
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup these will be stored within glob/input
						position !pair
						dimension !pair 
						label !string
						color !color 
						label-color !color
						min-dimension !pair
						font !any
						align !word 
					]
					
					;-            glob/gel-spec:
					; different AGG draw blocks to use, one per layer.
					; these are bound and composed relative to the input being sent to glob at process-time.
					gel-spec: [
						; event backplane
						none
						; marbles are just labels and don't trigger events.
						[]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						position dimension color label label-color min-dimension font align
						[
							line-width 2
							(
								either tuple? data/color= [
									compose [
										pen (data/color= ) 
										fill-pen (data/color=)
										box (data/position=) (data/position= + data/dimension= - 1x1) 3
									]
								][ [] ]
							)
							;pen (content* gel/glob/marble/frame/aspects/color)
							;line (data/position=) (data/position= + data/dimension=)
							;(prim-x data/position= data/dimension=  data/color= + 0.0.0.128 1)
							line-width 0
							pen none
							(
								prim-label data/label= data/position= + 1x0 data/dimension= data/label-color= data/font= data/align=
							)
							
;							line-width 1
;							pen (red) 
;							fill-pen (0.0.0.200 + data/color=)
;							box (data/position=) (data/position= + data/min-dimension=)
						]
							
						; controls layer
						;[]
						
						; overlay layer
						; like the bg, it may switched off, so don't depend on it.
						;[]
					]
				]
			]
			
			
			
			
			;-----------------
			;-        set-aspect()
			;
			; interface to safely access aspect object.  does not generate errors on inexisting aspect names
			;
			; does not access materials since these are considered private to the marble & glass.
			;-----------------
			set-aspect: func [
				marble [object!]
				aspect [word!]
				value 
				/local success?
			][
				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/set-aspect()}]
				success?: either in marble/aspects aspect [
					fill* marble/aspects/:aspect value
					vprobe aspect
					vprobe value
					true
				][
					vprint ["aspect '" to-string aspect " not in marble"]
					vprint "assigment ignored"
					false
				]
				vout
				marble: aspect: value: false
				success?
			]


		
			;-----------------
			;-        aspect-list()
			; abstraction, in case this changes.  also prettier in code.
			;-----------------
			aspect-list: func [
				marble
			][
				;vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/aspect-list()}]
				;vout
				next first marble/aspects
			]
			
			
			;-----------------
			;-        material-list()
			; abstraction, in case this changes.  also prettier in code.
			;-----------------
			material-list: func [
				marble
			][
				;vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/material-list()}]
				;vout
				next first marble/material
			]
			
			
			;-----------------
			;-        link-glob-input()
			;-----------------
			; if any aspect or material names match glob input names, we link the glob to the aspect.
			;
			; just a very quick and handy way to define a style without needing to code it.
			;
			; ATTENTION: if a material property has the same name as an aspect, IT will be linked to the glob 
			;            (materials have precedence).
			;
			; if your glob needs manual control over how it uses an aspect, just name it
			; differently in the gel and create your own custom linkage in setup-marble().
			;
			; because end users do not have access to the inner glob, this name differentiation isn't 
			; a big deal.  the default naming in custom linkage is to use the aspect prefixed with '*
			; such that the 'position aspect would become '*position in the gel.
			;-----------------
			link-glob-input: func [
				marble
				/using glob
				/local item plug input inputs
			][
				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/link-glob-input()}]
				
				; use default glob or supplied one
				glob: any [glob marble/glob]
				
				inputs: extract glob/input 2
				
				;v?? inputs
				
				; map each input to a matching aspect or material
				foreach item inputs [
					;vprint item
					case [
						plug: get in marble/material item [
							if all [
								object? plug
								in plug 'valve ; is this really a plug?
							][
								input: select glob/input item 
								;vprint ["linking input:" to-string item]
								input/valve/link/reset input plug
							]
						]
						plug: get in marble/aspects item [
							;------------
							; this is faster at run-time, but causes some interference because the inputs
							; are type-converting
							;
;								input: select glob/input item 
;								fill* input content*  plug
;								marble/aspects/:item: input

							input: select glob/input item 
							;vprint ["linking input:" to-string item]
							input/valve/link/reset input plug
							
						]
					]
				]
				vout
			]
			


			;-----------------
			;-        setup()
			;
			; low-level core marble setup.
			;
			; this setup expects you to be using the GLASS framework as-is, MODIFY AT OWN RISK.
			;
			; the reason liquid is used extensively in GLASS, is that it allows a lot of freedom in the setup
			; of a system without changing its interface.  If you use the aspects and gl-specify() function directly
			; glass might be completely replaced with new code and your application will still remain compatible.
			;
			; for example, a theme engine will be grafted to glass at some point, with no effect on your use
			; of the library, if you use the api exclusively.
			;
			; do not expect anything here to remain from version to version.
			;
			; the only valid interface to glass is via the style hooks, aspect plugs and public GLASS api module.
			;
			; this function mainly setups the internal glob requirements for marble and frames.
			; it also auto allocates aspects as plugs
			;
			; use setup-style() in styles which rely on default GLASS architecture, but require their own
			; specific intialisation.
			;-----------------
			setup: func [
				marble
				/local simple-aspects item
			][
				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/setup()}]
				; make an instance-specific property containers
				marble/aspects: make marble/aspects []
				marble/material: make marble/material []
				
				marble/options: copy []
				
				
				;----
				; allocate aspects automatically
				foreach item aspect-list marble [
					;vprint [ "adding aspect: " item "> " marble/aspects/:item]
					marble/aspects/:item: liquify*/fill !plug (either series? item: get in marble/aspects item [copy item][item])
				]

				;----
				; allocate materials, 
				;
				; you are actully free to use your own materials and link them however you like.
				; the framework is simply there to help you get started with a decent layout
				; without much work required for you to customize or enhance it.
				;
				; if you use custom material names, the default frame marble won't be able to link
				; your marbles so you'll have to adapt its fasten() method
				
				marble/valve/gl-materialize marble
				marble/valve/materialize marble


				; allocate our glob(s)
				either marble/valve/is-frame? [
				
					; this is only used as a stack.
					marble/glob: liquify* !glob
					marble/collection: copy []
					
					; if the frame has any visuals, create and link them.
					if marble/valve/bg-glob-class [
						marble/frame-bg-glob: liquify*/with marble/valve/bg-glob-class compose [marble: (marble)]
						marble/valve/link-glob-input/using marble marble/frame-bg-glob
						marble/glob/valve/link marble/glob marble/frame-bg-glob
					]
								
					if marble/valve/fg-glob-class [
						
						marble/frame-fg-glob: liquify*/with marble/valve/fg-glob-class compose [marble: (marble)]
						marble/valve/link-glob-input/using marble marble/frame-fg-glob
						
						; the fg glob will be unlinked and relinked everytime new marbles are collected
						marble/glob/valve/link marble/glob marble/frame-fg-glob
					]
				][
					marble/glob: liquify*/with any [marble/valve/glob-class !glob] compose [marble: (marble)]
					marble/valve/link-glob-input marble
				]
				
				

				; style-related setup
				marble/valve/setup-style marble

				vout
			]
			


			;-----------------
			;-        do-action()
			;
			; this is a high-level callback mechanism aimed at individual marbles
			;
			; when events occur for SOME actions, depending on the style, it
			; just calls [ do-action event ] and it will hook into the marble's action context.
			;
			; the specify dialect may modify an instance's action context
			;-----------------
			do-action: func [
				event
				/local action marble
			][
				;vin "do-action()"
				marble: event/marble
				;print marble/sid
				;print marble/valve/style-name
				if object? marble/actions [
					if function? action: get/any in marble/actions event/action [
						 action event
					]
				]
				;vout
			]
			


			
			;-----------------
			;-        test-handler()
			;
			; this handler is used for testing purposes only. 
			;-----------------
			test-handler: func [
				event [object!]
			][
				vin [{HANDLE MARBLE}]
				;vprint event/action
				switch event/action [
					start-hover [
						fill* event/marble/aspects/hover? true
					]
					
					end-hover [
						fill* event/marble/aspects/hover? false
					]
				]
				
				vout
				none
			]
			
			
			

			;-----------------
			;-        setup-style()
			;-----------------
			; a callback to extend anything in the marble AFTER Glass has finished with its own setup
			;
			; this is used by styles for their own custom data requirements.
			;
			; styles may also provide application setup hooks, but usually do so via extensions to the
			; the specification parser, using dialect()
			; 
			; most styles will also add default stream handlers (like viewports)
			;-----------------
			setup-style: func [
				marble
			][
				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/stylize()}]
				
				; just a quick stream handler for all marbles
				event-lib/handle-stream/within 'test-handler :test-handler marble
				vout
			]
			
		
			
			
			
			;-----------------
			;-        gl-materialize()
			;
			; low-level default GLASS material allocation & setup.
			;
			; the purpose is mainly to allow OTHER nodes (like glob inputs) to link TO the materials themselves.
			;
			; at this stage, you should not LINK the MATERIALS to other plugs, because a lot of things are
			; still unknown... like the marble's frame, children, etc.  in fact, The
			; internal globs don't even exist yet.
			;
			; you may replace this function to overide how default glass materials are built by your class.
			; but you will also have to provide your own fasten and make sure your marbles
			; cooperate properly with the frame they are collected in.
			;
			; Note that glass actively uses a feature of liquid which is called mutation. 
			; MUTATION CHANGES THE CLASS (VALVE) of a liquid plug without changing the instance
			; itself.  
			;
			; The default Glass framework only mutates materials, NEVER aspects.  furthermore, it ONLY mutates 
			; plugs it allocates itself, usually within gl-materialize.
			;
			; If you simply wish to EXTEND the default glass marbles, use the stylize() & materialize() functions.
			; For examples, look at the styles in the default stylesheet.
			;
			; eventually, a theme/skin engine will hookup within the materialization process somehow.
			;-----------------
			gl-materialize: func [
				marble [object!]
				/local mtrl
			][
				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/gl-materialize()}]
				; manage relative positioning
				;if relative-marble? marble [
					; ! junction is a default, but it may change via frame-managed mutation.
				
				mtrl: marble/material
				
				; these are managed by the frame (will be mutated by it!)
				mtrl/position: liquify*/fill epoxy-lib/!junction mtrl/position
				mtrl/dimension: liquify*/fill epoxy-lib/!junction mtrl/dimension

				; these are managed by ourself, but will be used by our frame
				
				; the automatic label resizing is optional in marbles.
				either 'automatic = get in marble 'label-auto-resize-aspect [
					mtrl/min-dimension: liquify* epoxy-lib/!label-min-size
				][
					mtrl/min-dimension: liquify*/fill !plug mtrl/min-dimension
				]
				mtrl/fill-weight: liquify*/fill !plug mtrl/fill-weight
				mtrl/fill-accumulation: liquify*/fill !plug mtrl/fill-accumulation
				mtrl/stretch: liquify*/fill !plug mtrl/stretch

				;]
				
				vout
			]
			
			
			
			;-----------------
			;-        materialize()
			; style-oriented public materialization.
			;
			; called just after gl-materialize()
			;
			; note materializtion occurs BEFORE the globs are linked, so allocate any
			; material nodes it expects to link to here, not in setup-style().
			;
			; read the materialize() function notes above for more details, which also apply here.
			;-----------------
			materialize: func [
				marble
			][
				;vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/materialize()}]
				;vout
			]
			
			
			



			;-----------------
			;-        gl-fasten()
			;
			; low-level default GLASS fastening.
			;
			; perform all linkeage required for this marble to effectively layout.
			;
			; usually, control-type marbles do not connect to their frames at this step, since 
			; the frame is responsable for allocation and linking marbles between themselves...
			;
			; use this when a style requires a special trick which is simple to perform 
			; here and won't break the frame's expectations.
			;
			; be extra carefull not to create link cycles, which will be detected and
			; generate an error by liquid (by default).
			;
			; the frame will always call fasten on the marble BEFORE it performs its own
			; fastening on the marble, so any link you do here will be at the head of the
			; subordinate block
			;
			; note, fasten() on a marble is ONLY called from frames ... control-type
			; marbles should never call gl-fasten() directly !!
			;
			;-----------------
			gl-fasten: func [
				marble
			][
				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/gl-fasten()}]
				
				; the automatic label resizing is optional in marbles.
				;
				; current acceptible values are ['automatic | 'disabled]
				if 'automatic = get in marble 'label-auto-resize-aspect [
					link*/exclusive marble/material/min-dimension marble/aspects/size
					link* marble/material/min-dimension marble/aspects/label
					link* marble/material/min-dimension marble/aspects/font
					link* marble/material/min-dimension marble/aspects/padding
					;print "!!!!!!!!!!!!"
					;ask "@"
				]
				
				
				
				; perform any style-related fastening.
				marble/valve/fasten marble
				vout
			]
			
			
						
			;-----------------
			;-        fasten()
			;
			; style-oriented public fasten call.  called at the end of gl-fasten()
			;
			;-----------------
			fasten: func [
				marble
			][
				;vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/fasten()}]
				;vout
			]
			


			

			;-----------------
			;-        gl-specify()
			;
			; parse a specification block during initial layout operation
			;
			; can also be used at run-time to set values in the aspects block directly by the application.
			;
			; but be carefull, as some attributes are very heavy to use like frame sub-marbles, which will 
			; effectively trash their content and rebuild the content again, if used blindly, with the 
			; same spec block over and over.
			;
			; the marble we return IS THE MARBLE USED IN THE LAYOUT
			;
			; so the the spec block can be used to do many wild things, even change the 
			; marble type and add items to marble, on the fly!!
			;-----------------
			gl-specify: func [
				marble [object!]
				spec [block!]
				stylesheet [block!] "Required so stylesheet propagates in marbles we create"
				/wrapper
				;/local mbl
			][
				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/gl-specify()}]
				
				if wrapper [
					include marble/options 'wrapper
				]

				
				if function? get in marble/valve 'pre-specify [
					marble/valve/pre-specify marble stylesheet
				]
				
				marble: any [
					marble/valve/specify marble spec stylesheet
					marble
				]
				
				if function? get in marble/valve 'post-specify [
					marble/valve/post-specify marble stylesheet
				]
				
				vout
				
				marble
			]

			;-----------------
			;-        specify()
			;
			; parse a specification block during initial layout operation
			;
			; can also be used at run-time to set values in the aspects block directly by the application.
			;
			; but be carefull, as some attributes are very heavy to use like frame sub-marbles, which will 
			; effectively trash their content and rebuild the content again, if used blindly, with the 
			; same spec block over and over.
			;
			; the marble we return IS THE MARBLE USED IN THE LAYOUT
			;
			; so the the spec block can be used to do many wild things, even change the 
			; marble type or instance on the fly!!
			;
			; we now call the dialect() function which allows one to reuse the internal specify
			; dialect directly.
			;
			; dialect will simply be called after specify is done.
			;-----------------
			specify: func [
				marble [object!]
				spec [block!]
				stylesheet [block!] "Required so stylesheet propagates in marbles we create"
				/local data pair-count tuple-count
			][
				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/specify()}]
				
				pair-count: 0
				tuple-count: 0
				parse spec [
					any [
						copy data ['with block!] (
							;print "SPECIFIED A WITH BLOCK"
							;marble: make marble data/2
							;liquid-lib/reindex-plug marble
							do bind/copy data/2 marble 
							
						) | 
						'stiff (
							fill* marble/material/fill-weight 0x0
						) |
						'stretch set data pair! (
							fill* marble/material/fill-weight data
						) |
						'left (
							fill* marble/aspects/align 'WEST
						) |
						'right (
							fill* marble/aspects/align 'EAST
						) |
						'padding set data [pair! | integer!] (
							fill* marble/aspects/padding 1x1 * data
						) |
						set data tuple! (
							tuple-count: tuple-count + 1
							switch tuple-count [
								1 [set-aspect marble 'label-color data]
								2 [set-aspect marble 'color data]
							]
							
						) |
						set data pair! (
							pair-count: pair-count + 1
							switch pair-count [
								1 [	fill* marble/material/min-dimension data ]
								2 [	set-aspect marble 'offset data ]
							]
						) |
						set data string! (
							set-aspect marble 'label data
						) |
						set data block! (
							; an action (by default)
							if object? get in marble 'actions [
								marble/actions: make marble/actions [release: make function! [event] bind/copy data marble]
							]
						) |
						skip 
					]
				]
				
				; give custom marbles, a chance to setup their own dialect or alter this one.
				marble/valve/dialect marble spec stylesheet
				
				vout
				;ask ""
				marble
			]
			
			
			
			;-----------------
			;-        dialect()
			;
			; this uses the exact same interface as specify but is meant for custom marbles to 
			; change the default dialect.
			;
			; note that the default dialect is still executed, so you may want to "undo" what
			; it has done previously.
			;
			;-----------------
			dialect: func [
				marble [object!]
				spec [block!]
				stylesheet [block!] "Required so stylesheet propagates in marbles we create"
			][
				;vin [{dialect()}]
				;vout
			]
			

			
						
			;-----------------
			;-        isolate()
			;
			; a stub for a marble to detach itself from its frame
			;-----------------
			isolate: func [
				marble
			][
				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/isolate()}]
				if object? marble/frame [
					marble/frame/valve/detach marble/frame marble
				]
				vout
			]
			
			

			
			;-----------------
			;-        process()
			;-----------------
			; this plug returns itself, so far nothing special.
			;
			; for now there is no glass-based use of the !marble as a plug.
			process: func [
				marble data
			][
				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/process()}]
				marble/liquid: marble
				vout
			]
		]
	]
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %marble.r 
    date: 25-Jun-2010 
    version: 0.5.4 
    slim-name: 'marble 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: MARBLE
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: GLASS  v0.1.0
;--------------------------------------------------------------------------------

append slim/linked-libs 'glass
append/only slim/linked-libs [


;--------
;-   MODULE CODE


;- slim/register/header
slim/register/header [

	; declare words so they stay bound locally to this module
	!plug: liquify*: content*: fill*: link*: unlink*: content*: none
	


	;- LIBS
	liquid-lib: slim/open/expose 'liquid none [!plug [liquify* liquify ] [content* content] [fill* fill] [link* link] [unlink* unlink]]
	
	; sillica words to declare
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: layout: none
	screen-size: none
	sl: slim/open/expose 'sillica none [
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		layout
		screen-size
	]
	epoxy-lib: slim/open/expose 'epoxy none [!box-intersection !pin]
	
	;- EVENT MANAGEMENT OVERHAUL
	event-lib: slim/open 'event none
	
	;- load default stylesheet
	slim/open 'glaze none


	glaze-lib: slim/open 'glaze none
	glue-lib: slim/open 'glue none
	
	
	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;
	
	
	;--------------------------------------------------------
	;-   
	;- HIGH-LEVEL API
	;
	;-----------------



	;-----------------
	;-     set-aspect()
	;
	; API stub for marble's internal set-aspect function.
	;
	; returns true or false if assignment was possible or not.
	;-----------------
	set-aspect: func [
		marble [object!]
		aspect [word!]
		value 
	][
		vin [{glass/set-aspect()}]
		value: marble/valve/set-aspect marble aspect value
		vout
		value
	]
			
	
	
	

	;-----------------
	;-     request()
	;
	; adds a requestor to the overlay, triggers input blocker
	;
	; if overlay is a block, layout is called on it directly.
	;-----------------
	request: func [
		title [string!]
		viewport [object! none!] "be carefull giving a none! here, last opened window MUST BE A GLASS WINDOW"
		req [object! block!]
		/non-blocking "Do not trigger input blocker"
		/modal
		/size sz [pair!]
		/local trigger 
	][
		vin [{glass/request()}]
		
		if block? req [
			req: layout/within/options req 'requestor reduce [title]
		]
		
		fasten req

		viewport: any [viewport default-viewport]
		
		req/viewport: viewport
		
		trigger: any [
			all [non-blocking 'ignore]
			all [modal 'ignore]
			'remove
		]
		
		pin req viewport 'center 'center
		
		add-overlay req viewport trigger
		
		if size [
			fill* req/material/dimension sz
		]
		
		if modal [
			hold
		]
		
		vout
		req
	]
	
	;-----------------
	;-     hide-request()
	;-----------------
	hide-request: func [
		req [object! none!]
		/local viewport
	][
		vin [{glass/hide-request()}]
		
		viewport: any [
			all [
				req 
				req/viewport
			]
			default-viewport
		]
		remove-overlay viewport
		
		vout
	]
	
	
	;- REQUESTORS
	;-----------------
	;-     request-string()
	;-----------------
	request-string: func [
		title [string!]
		/local fld rval
	][
		vin [{request-string()}]
		request/modal title none [
			column 20x10 [
				fld: field 200x23
			]
			row [
				hstretch
				button 75x23 stiff "Ok" [rval: content* fld/aspects/label hide-request none resume]
				button 75x23 stiff "Cancel" [hide-request none resume ]
			]
		]
		vout
		rval
	]
	
	
	;-----------------
	;-     request-confirmation()
	;-----------------
	request-confirmation: func [
		title [string!]
		/message msg [string!]
		/labels lbl-ok [string!] lbl-cancel [string!]
		/local rval 
	][
		vin [{request-confirmation()}]
		lbl-ok: any [lbl-ok "Ok"]
		lbl-cancel: any [lbl-cancel "Cancel"]
		request/modal title none compose/deep [
			(
				either msg [
					compose [	
						auto-label (msg)
					]
				][
					[]
				]
			)
			row 50x20 [
				hstretch
				button 75x23 stiff (lbl-ok) [rval: true hide-request none resume]
				button 75x23 stiff (lbl-cancel) [hide-request none resume ]
				hstretch
			]
		]
		vout
		rval
	]
	
	
	;-----------------
	;-     request-inform()
	;-----------------
	request-inform: func [
		title [string!]
	][
		vin [{request-inform()}]
		request/modal title none [
			row 50x20 [
				hstretch
				button 75x23 stiff "Ok" [rval: true hide-request none resume]
				hstretch
			]
		]
		vout
	]
	
	
	
	
	;- EVENT-LIB RELATED STUFF
	
	;-----------------
	;-     hold()
	;
	; stub to event/interrupt to hold the current interpreter until event/resume is used.
	;-----------------
	hold: does [
		event-lib/hold
	]
	
	;-----------------
	;-     resume()
	;
	; stub to event/resume
	;-----------------
	resume: does [
		event-lib/resume
	]
	
	;-----------------
	;-     add-hot-key-handler()
	;-----------------
	add-hot-key-handler: func [
		key
	][
		vin [{add-hot-key-handler()}]
		;append event-lib/hot-keys
		vout
	]
	
		
	
	
	
	;-----------------
	;-     refresh()
	;
	; do not call this within event handling as it will enter an endless loop.
	;-----------------
	refresh: func [
		vp [object!]
	][
		vin [{refresh()}]
		event-lib/queue-event [action: 'refresh viewport: vp]
		event-lib/do-queue ;dispatch-event-port	
		vout
	]

	
	;-----------------
	;-     add-overlay()
	;-----------------
	add-overlay: func [
		overlay [object!]
		viewport [object!]
		trigr [word! object! block!]
	][
		vin [{add-overlay()}]
		
		; this is required or else queue-event tries to use the word as a variable
		either word? trigr [
			;print "@@@@@@@@@@@@@@@"
			trigr: reduce [to-lit-word trigr]
		][
			trigr: reduce [trigr]
		]
		
		;v?? trigr
		event-lib/queue-event compose/only [
			action: 'add-overlay
			
			; the glob we want to overlay
			frame: overlay
			
			; in what viewport (window?) to show this overlay
			viewport: (viewport)
			
			; the event(s) to trigger when input-blocker is clicked on.
			; note: if this is none, input-blocker is not enabled.
			;
			; if set to 'remove  then the trigger is the default, which
			; simply removes the overlay and disables input-blocker.
			;
			; if set to 'ignore, nothing happens, you'll require some sort
			; of explicit mechanism to call remove-overlay.
			trigger: (first trigr)
			
		]
		vout
	]
	
	

	
	;-----------------
	;-     remove-overlay()
	;-----------------
	remove-overlay: func [
		viewport [object!]
	][
		vin [{remove-overlay()}]
		event-lib/queue-event compose/only [
			action: 'remove-overlay
			
			; in what viewport (window?) to show this overlay
			viewport: (viewport)
		]
		vout
	]
	
	

	
	
	
	;-----------------
	;-     pin()
	;
	; pins one marble (offset) according to another marble (offset & dimension).
	; 
	; this function will temporarily enable cycle checks in liquid and restore its previous
	; state on exit.  We do this since its a high-level function and these should not
	; allow a deadlock by default.
	;
	; if you really know what you are doing, you may use the /expert mode which doesn't
	; activate cycle checking.
	;
	; the coordinates are determined using any of:
	; 
	;  center,  
	;  top, T, bottom, B, right, R, left, L
	;  north, N, south, S, east, E, west, W
	;  top-left, TL, top-right, TR, bottom-left, BL, bottom-right, BR
	;  north-west, NW, north-east, NE, south-west, SW, south-east, SE
	;  
	;-----------------
	pin: func [
		marble [object!]
		ref-marble [object!]
		pin-from [word!]
		pin-to [word!]
		/expert "doesn't activate cycle checking, which might slow down operation a lot."
		/offset off [object! pair!] "if its a pair, will fill marble/aspects/offset, on-the-fly"
		/local pin cycle?
	][
		vin [{pin()}]
		pin: marble/material/position
		
		unless expert [
			cycle?: liquid-lib/check-cycle-on-link?
			liquid-lib/check-cycle-on-link?: true
		]
		
		; first we mutate the marble's offset so its a pin node
		pin/valve: !pin/valve

		; then we reset its connection and piping
		unlink*/detach pin
		
		; we fill it with both pin coordinates
		fill* pin reduce [pin-from pin-to]
		pin/resolve-links?: true
		
		link* pin reduce [
			marble/material/dimension
			ref-marble/material/position
			ref-marble/material/dimension
		]
		
		if pair? off [
			fill* marble/aspects/offset off
			link* pin marble/aspects/offset
		]
		
		if object? off [
			link* pin off
		]
		
		
		unless expert [
			liquid-lib/check-cycle-on-link?: cycle?
		]
		
		;probe "PIN:"
		;epoxy-lib/von
		;probe content* pin
		;epoxy-lib/voff
		vout
	]
	
	
	;-----------------
	;-     stretch()
	;-----------------
	stretch: func [
		marble [object!]
		ref-marble [object!]
		size-from [word! none!]
		size-to [word! none!]
		/add s [object! pair!] "if its a pair, will create a plug, on-the-fly"
	][
		vin [{stretch()}]
		vout
	]
	
	
	

	;-----------------
	;-     collect()
	;-----------------
	collect: func [
		frame [object!]
		marble [object!]
		/top
		/only
	][
		vin [{collect-marble()}]
		either top [
			frame/valve/gl-collect/top frame marble
		][
			frame/valve/gl-collect frame marble
		]
		unless only [
			fasten marble
			fasten frame
		]
		vout
	]
	
	
	
	
	
	
	;-----------------
	;-     discard()
	;-----------------
	discard: func [
		frame [object!]
		marble [object! block! word!]
		/only
	][
		vin [{collect-marble()}]
		frame/valve/gl-discard frame marble
		unless only [
			fasten frame
		]
		vout
	]
	
	
	;-----------------
	;-     fasten()
	;-----------------
	fasten: func [
		marble [object!]
	][
		vin [{fasten()}]
		marble/valve/gl-fasten marble
		vout
		marble
	]
	
	
	
	;- FOCUS control
	;-----------------
	;-    focus()
	;-----------------
	focus: func [
		marble [object!]
		/local window
	][
		vin [{focus()}]
		
		if window: search-parent-frames marble 'window [
			window: last window
			event-lib/queue-event compose [
				action: 'focus 
				marble: (marble)
				view-window: window/view-face
			]
		]
		vout
	]
	
	
	;-----------------
	;-    unfocus()
	;-----------------
	unfocus: func [
		marble
	][
		vin [{unfocus()}]
		if window: search-parent-frames marble 'window [
			window: last window
			event-lib/queue-event compose [
				action: 'unfocus 
				marble: (marble)
				view-window: window/view-face
			]
		]
		vout
	]
	
	
	
	
	
	;- OTHER

	
	;-----------------
	;-     search-parent-frames()
	;
	; <TO DO> support block! input
	;
	; returns first parent with valve/style-name set in criteria
	;-----------------
	search-parent-frames: func [
		marble [object!]
		criteria [string! integer! issue! word! tuple!]
		/id "searches usr-id in frames"
		/local frm rdata
	][
		vin [{glass/search-paren-frames()}]
		if frm: marble/frame [
			case [
				id [
					until [
						if frm/user-id = criteria [
							append any [rdata rdata: copy []] frm
						]
						none? frm: frm/frame
					]
				]
				
				true [
					criteria: to-word to-string criteria
					until [
						if frm/valve/style-name = criteria [
							append any [rdata rdata: copy []] frm
						]
						none? frm: frm/frame
					]
				]
			]
		]
		vout
		rdata
	]
	
	
			



	;-----------------
	;-     stylesheet-info()
	; display data about a stylesheet
	;-----------------
	stylesheet-info: func [
		/of s "specify a stylesheet to display"
	][
		vin [{stylesheet-info()}]
		s: any [s master-stylesheet]
		s: list-stylesheet/using s
		
		sort s
		
		new-line/all s true
		
		s: mold s
		insert s "styles in stylesheet:^/"
		vprint "styles in stylesheet:"
		vout
		s
	]
	
	
	
	;-----------------
	;-     default-viewport()
	;-----------------
	default-viewport: does [
		get in last system/view/screen-face/pane 'viewport
	]
	
	
	
	;-----------------
	;-     api-von()
	;-----------------
	api-von: func [
		
	][
		vin [{api-von()}]
		event-lib/von
		glue-lib/von
		epoxy-lib/von
		sl/von
		vout
	]
	
	;-----------------
	;-     styles-von()
	;-----------------
	styles-von: func [
	][
		vin [{styles-von()}]
		glaze-lib/styles-von
		vout
	]
	
	
	
	
	
	
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %glass.r 
    date: 20-Jun-2010 
    version: 0.1.0 
    slim-name: 'glass 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: GLASS
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: GLAZE  v0.5.0
;--------------------------------------------------------------------------------

append slim/linked-libs 'glaze
append/only slim/linked-libs [


;--------
;-   MODULE CODE




slim/register/header [

	;- LIBS

	!plug: liquify*: content*: fill*: link*: unlink*: none
	liquid-lib: slim/open/expose 'liquid none [!plug [liquify* liquify ] [content* content] [fill* fill] [link* link] [unlink* unlink]]

	
	!glob: to-color: none
	glob-lib: slim/open/expose 'glob none [!glob to-color]
	
	sl: slim/open 'sillica none
	marble: slim/open 'marble none
	frame: slim/open 'frame none
	window: slim/open 'window none
	field: slim/open 'style-field none
	script-editor: slim/open 'style-script-editor none
	button: slim/open 'style-button none
	list: slim/open 'style-list none
	scroller: slim/open 'style-scroller none
	choice: slim/open 'style-choice none
	droplist: slim/open 'style-droplist none
	requestor: slim/open 'requestor  none
	progress: slim/open 'style-progress none
	group-sl: slim/open 'group-scrolled-list none
	scroll-frm: slim/open 'scroll-frame none
	;frm-scroll: slim/open 'group-scrollframe none
	pane: slim/open 'pane none
	
	toggle: slim/open 'style-toggle none
	icon: slim/open 'style-icon-button none
	image: slim/open 'style-image none
	
	; build the default glass stylesheet
	
	;- FRAMES
	column: make frame/!frame [layout-method: 'column]
	row: make frame/!frame [layout-method: 'row]
	
	sl/collect-style/as make column [aspects: make aspects [frame-color: none]] 'column
	sl/collect-style/as make column [aspects: make aspects []] 'vframe
	sl/collect-style/as make row [aspects: make aspects [frame-color: none] ] 'row
	sl/collect-style/as make row [aspects: make aspects []] 'hframe
	
	sl/collect-style scroll-frm/!scroll-frame
	
	
	
	;sl/collect-style frm-scroll/!scroll-frame
	sl/collect-style pane/!pane
	
	;-      vcavity
	sl/collect-style/as vcavity: make column [
		;-           aspects[]
		aspects: make aspects [
			;-               color:
			color: none ; default is to use bg
			
			;-               frame-color:
			frame-color: theme-border-color
		]

		;-           material[]
		material: make material [
			;-               border-size:
			border-size: 10x10
		]
		
		

		valve: make valve [
			
			;-----------------
			;-               dialect()
			;-----------------
			dialect: func [
				marble [object!]
				spec [block!]
				stylesheet [block!] "Required so stylesheet propagates in marbles we create"
			][
				vin [{dialect()}]
				parse spec [
					any [
						'no-border (
							fill* marble/aspects/frame-color none
						)
						
						| skip
					]
				]				vout
			]
		
		
			fg-glob-class: none
			bg-glob-class: make glob-lib/!glob [
				valve: make valve [
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup  these will be stored within the instance under input
						position !pair 
						dimension !pair
						color !color (blue)
						frame-color  !color 
						;clip-region !block ([0x0 1000x1000])
						;parent-clip-region !block ([0x0 1000x1000])
					]
					
					;-            glob/gel-spec:
					gel-spec: [
						; event backplane
						none
						[]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						 position dimension color frame-color ;clip-region parent-clip-region
						[
							(sl/prim-cavity/all/colors data/position= data/dimension= - 1x1 data/color= data/frame-color=)
			
						]
						
						; controls layer
						;[]
						
					]
				]
			]
		]
	] 'vcavity
	
	sl/collect-style/as make vcavity [ layout-method: 'row ] 'hcavity



	;-      tool-row
	sl/collect-style/as make row [
		;-           aspects[]
		aspects: make aspects [
			;-               color:
			color: none ; default is to use bg
			
			;-               corner:
			corner: 0
			
			
			;-               size:
			size: none
			
			
			;-               frame-color:
			frame-color: theme-border-color
		]

		;-           material[]
		material: make material [
			;-               border-size:
			border-size: 5x5
			
			;-               fill-weight:
			fill-weight: 1x1
			
		]

		valve: make valve [
			fg-glob-class: none
			bg-glob-class: make glob-lib/!glob [
				valve: make valve [
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup  these will be stored within the instance under input
						position !pair 
						dimension !pair
						color !color (blue)
						frame-color  !color
						corner !integer
						;clip-region !block ([0x0 1000x1000])
						;parent-clip-region !block ([0x0 1000x1000])
					]
					
					;-            glob/gel-spec:
					gel-spec: [
						; event backplane
						none
						[]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						 position dimension color frame-color corner ;clip-region parent-clip-region
						[
							pen none
;							; bottom shadow
;							fill-pen linear (data/position= + (data/dimension= * 0x1)) 1 (10) 90 1 1 
;								(0.0.0.120) 
;								(0.0.0.240) 
;								(0.0.0.255 )
;							box (data/position= + (data/dimension= * 0x1) - 0x3) (data/position= + data/dimension= + 0x10) (data/corner=)
;							
							line-width 1
							;pen (any [data/frame-color= theme-frame-color])
							fill-pen linear (data/position= ) 1 (data/dimension=/y) 90 1 1 
								(theme-bg-color * 1.1)
								(theme-bg-color * 1)
								(theme-bg-color * .9)
							box (data/position=) (data/position= + data/dimension= ) (data/corner=)
							
			
						]
						
						; controls layer
						;[]
						
					]
				]
			]
		]
	] 'tool-row


		;-      title-bar
	sl/collect-style/as make row [
		;-           aspects[]
		aspects: make aspects [
			;-               color:
			color: none ; default is to use bg
			
			;-               corner:
			corner: 3
			
			
			;-               size:
			size: none
			
			
			;-               frame-color:
			frame-color: theme-border-color
		]

		;-           material[]
		material: make material [
			;-               border-size:
			border-size: 5x5
			
			;-               fill-weight:
			fill-weight: 1x1
			
		]

		valve: make valve [
			fg-glob-class: none
			bg-glob-class: make glob-lib/!glob [
				valve: make valve [
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup  these will be stored within the instance under input
						position !pair 
						dimension !pair
						color !color (blue)
						frame-color  !color
						corner !integer
						;clip-region !block ([0x0 1000x1000])
						;parent-clip-region !block ([0x0 1000x1000])
					]
					
					;-            glob/gel-spec:
					gel-spec: [
						; event backplane
						none
						[]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						 position dimension color frame-color corner ;clip-region parent-clip-region
						[
							pen none
;							; bottom shadow
;							fill-pen linear (data/position= + (data/dimension= * 0x1)) 1 (10) 90 1 1 
;								(0.0.0.120) 
;								(0.0.0.240) 
;								(0.0.0.255 )
;							box (data/position= + (data/dimension= * 0x1) - 0x3) (data/position= + data/dimension= + 0x10) (data/corner=)
;							
							line-width 1
							pen (any [data/frame-color= theme-frame-color])
							fill-pen white
							box (data/position=) (data/position= + data/dimension= - 1x1)
;							fill-pen linear (data/position= ) 1 (data/dimension=/y) 90 1 1 
;								(theme-bg-color * 1.1)
;								(theme-bg-color * 0.9)
;								(theme-bg-color * 0.7)
							(sl/prim-glass (data/position=) (data/position= + data/dimension= - 1x1) theme-color 205)
			
						]
						
						; controls layer
						;[]
						
					]
				]
			]
		]
	] 'title-bar


	
	;-      vdrop-frame
	sl/collect-style/as vdrop-frame: make column [
		;-           aspects[]
		aspects: make aspects [
			;-               color:
			color: none ; default is to use bg
			
			;-               frame-color:
			frame-color: theme-border-color
		]

		;-           material[]
		material: make material [
			;-               border-size:
			border-size: 10x10
		]

		valve: make valve [
			fg-glob-class: none
			bg-glob-class: make glob-lib/!glob [
				valve: make valve [
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup  these will be stored within the instance under input
						position !pair 
						dimension !pair
						color !color (blue)
						frame-color  !color 
						;clip-region !block ([0x0 1000x1000])
						;parent-clip-region !block ([0x0 1000x1000])
					]
					
					;-            glob/gel-spec:
					gel-spec: [
						; event backplane
						none
						[]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						position dimension color frame-color ;clip-region parent-clip-region
						[
							pen none
							; top shadow
							fill-pen linear (data/position= ) 1 (10) 90 1 1 
								(0.0.0.120) 
								(0.0.0.240) 
								(0.0.0.255 )
							box (data/position=) (data/position= + data/dimension= - 1x1) 3
							
							fill-pen none
							pen (any [data/frame-color= theme-frame-color])
							line-width 1
							box (data/position=) (data/position= + data/dimension= - 1x1) 3
						]
						
						; controls layer
						;[]
						
					]
				]
			]
		]
	] 'vdrop-frame
	
	sl/collect-style/as make vdrop-frame [ layout-method: 'row ] 'hdrop-frame
	
	
	;- LAYOUT CONTROL
	;sl/collect-style marble/!marble
	sl/collect-style/as make marble/!marble [
		aspects: make aspects [label: none ]
		material: make material [fill-weight: 1x1]
	] 'elastic
	
	sl/collect-style/as make marble/!marble [
		aspects: make aspects [label: none ]
		material: make material [fill-weight: 1x0 min-dimension: 0x0]
	] 'hstretch
	
	sl/collect-style/as make marble/!marble [
		aspects: make aspects [label: none]
		material: make material [fill-weight: 0x1  min-dimension: 0x0]
	] 'vstretch
	
	sl/collect-style/as make marble/!marble [
		aspects: make aspects [label: none ]
		material: make material [fill-weight: 0x0 min-dimension: 20x20]
	] 'pad
	
	
	;- SEPARATORS
	;-     shadows
	shadow-separator: sl/collect-style/as make marble/!marble [
		aspects: make aspects [label: none]
		material: make material [fill-weight: 0x0 min-dimension: 3x3 ]


		valve: make valve [
			
			setup-style: func [
				marble
			][
				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/stylize()}]
				vout
			]
			
			
			glob-class: make glob-class [
			
				valve: make valve [

					input-spec: [
						; list of inputs to generate automatically on setup these will be stored within glob/input
						position !pair
						dimension !pair 
					]
					gel-spec: [
						; event backplane
						none
						[]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						position dimension
						[
							line-width 1
							pen  (0.0.0.128)
							line  (data/position= + (0x1 * data/dimension= - 0x3)) (data/position= + data/dimension= - 0x3)
							pen (0.0.0.200)
							line  (data/position= + (0x1 * data/dimension= - 0x2)) (data/position= + data/dimension= - 0x2)
							pen (0.0.0.240)
							line  (data/position= + (0x1 * data/dimension= - 0x1)) (data/position= + data/dimension= - 0x1)
						]
					]
				]
			]
		]
	] 'shadow-hseparator

	sl/collect-style/as make shadow-separator [
		valve: make valve [
			glob-class: make glob-class [
				valve: make valve [
					gel-spec: [
						; event backplane
						none
						[]
						
						
						; fg layer
						position dimension
						[
							pen (0.0.0.240)
							line  (data/position= + (0x1 * data/dimension= - 3)) (data/position= + data/dimension= - 0x3)
							pen (0.0.0.200)
							line  (data/position= + (0x1 * data/dimension= - 2)) (data/position= + data/dimension= - 0x2)
							pen (0.0.0.128)
							line  (data/position= + (0x1 * data/dimension= - 1)) (data/position= + data/dimension= - 0x1)
						]
					]
				]
			]
		]
	] 'upshadow-hseparator
		
	
	
	
	;- LABELS
	sl/collect-style/as make marble/!marble [ aspects: make aspects [font: theme-title-font] ] 'Title
	sl/collect-style/as make marble/!marble [ aspects: make aspects [font: theme-subtitle-font] ] 'SubTitle
	sl/collect-style/as make marble/!marble [ aspects: make aspects [font: theme-headline-font] ] 'headline
	sl/collect-style/as make marble/!marble [ aspects: make aspects [font: theme-label-font] ] 'Label
	sl/collect-style/as make marble/!marble [ aspects: make aspects [font: make theme-label-font [bold?: true]] ] 'bold-Label
	auto-lbl: sl/collect-style/as make marble/!marble [
		aspects: make aspects [font: theme-label-font]
		label-auto-resize-aspect: 'automatic
	] 'auto-label
	
	sl/collect-style/as make auto-lbl [
		aspects: make aspects [font: make font [bold?: true]]
	] 'auto-bold-label
	
	sl/collect-style/as make marble/!marble [
		aspects: make aspects [
			font: theme-title-font
			padding: 3x0
		]
		label-auto-resize-aspect: 'automatic
	] 'auto-title
	
	sl/collect-style/as make marble/!marble [
		aspects: make aspects [
			font: theme-subtitle-font
			padding: 3x0
		]
		label-auto-resize-aspect: 'automatic
	] 'auto-subtitle
	
	sl/collect-style/as make marble/!marble [
		aspects: make aspects [
			font: theme-requestor-title-font
		]
		label-auto-resize-aspect: 'automatic
	] 'requestor-title
	
	
	
	
	

	;- GAUGES
	sl/collect-style progress/!progress
	
	
	;- IMAGE DISPLAY
	sl/collect-style image/!image

	;- CONTROLS
	sl/collect-style field/!field
	sl/collect-style script-editor/!editor
	sl/collect-style/as make field/!field [material: make material [ min-dimension: 20x25]] 'short-field 
	sl/collect-style scroller/!scroller


	;- BUTTONS
	;-     button
	sl/collect-style button/!button
	sl/collect-style toggle/!toggle
	sl/collect-style icon/!icon
	sl/collect-style/as make icon/!icon [icon-set: 'toolbar] 'tool-icon
	
	sl/collect-style/as make button/!button [aspects: make aspects [font: make font [bold?: false]]] 'thin-button
	
	
	;-     link-button
	sl/collect-style/as make button/!button [
		
		
		;-         label-auto-resize-aspect:
		label-auto-resize-aspect: 'automatic
		
		
		aspects: make aspects [
			label: "link" 
		
			size: -1x-1
			
			font: theme-small-knob-font
			
			padding: 5x2
		]
		
		valve: make valve [
			glob-class: make glob-class [
			
				valve: make valve [

					gel-spec: [
						; event backplane
						position dimension 
						[
							line-width 1 
							pen none 
							fill-pen (to-color gel/glob/marble/sid) 
							box (data/position=) (data/position= + data/dimension= - 1x1)
						]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						position dimension color label-color label align hover? focused? selected? padding font
						[
							(
								any [
									all [ data/hover?= data/selected?= compose [
										; bg color
										pen none
										line-width 0
										fill-pen linear (data/position=) 1 (data/dimension=/y) 90 1 1 ( data/color= * 0.6 + 128.128.128) ( data/color= ) (data/color= * 0.7 )
										box (data/position= + 1x1) (data/position= + data/dimension= - 1x1) 4

										; shine
										pen none
										fill-pen (data/color= * 0.7 + 140.140.140.128)
										box ( sl/top-half  data/position= data/dimension= ) 4
										
										;inner shadow
										pen shadow ; 0.0.0.50
										line-width 2
										fill-pen none
										box (data/position= + 1x1) (data/position= + data/dimension= - 2x2) 4

										pen none
										line-width 0
										fill-pen linear (data/position=) 1 (data/dimension=/y) 90 1 1 ( data/color= * 0.6 + 128.128.128) ( data/color= ) (data/color= * 0.7 )
										box (pos: (data/position= + (data/dimension= * 0x1) - -2x10)) (data/position= + data/dimension= - 2x1) 4

										; border
										fill-pen none
										line-width 1
										pen  theme-knob-border-color
										box (data/position= ) (data/position= + data/dimension= - 1x1) 5

										(
										either data/hover?= [
											compose [
												line-width 1
												pen none
												fill-pen (theme-glass-color + 0.0.0.200)
												;pen theme-knob-border-color
												box (data/position= + 3x3) (data/position= + data/dimension= - 3x3) 2
											]
										][[]]
										)

										]
									]
									
									; default
									all [ data/hover?= compose [
										(
											sl/prim-knob 
												data/position= 
												data/dimension= - 1x1
												data/color=
												theme-knob-border-color
												'horizontal ;data/orientation=
												1
												4
										)
									]]
								]
							)
							line-width 0.5
							pen none ;(data/label-color=)
							fill-pen (data/label-color=)
							; label
							(sl/prim-label/pad data/label= data/position= + 1x0 data/dimension= data/label-color= data/font= data/align= data/padding=)
							
							
							
						]
							
						; controls layer
						;[]
						
						; overlay layer
						; like the bg, it may switched off, so don't depend on it.
						;[]
					]
				]
			]
		]
	] 'link-button
	

	;- COMPLEX styles
	sl/collect-style list/!list
	sl/collect-style droplist/!droplist
	
	
	;- POP-UP styles
	sl/collect-style choice/!choice
	
	
	;- GROUP styles
	;sl/collect-style group-field/!group-field
	sl/collect-style group-sl/!scrolled-list
	
	
	;- WINDOWS 
	sl/collect-style window/!window
	
	;- REQUESTORS
	sl/collect-style requestor/!requestor
	
	
	
	
	;- FUNCTIONS
	
	;-----------------
	;-     styles-von()
	;-----------------
	styles-von: func [
		
	][
		vin [{massive-von()}]
		window/von
		group-sl/von
		list/von
		vout
	]
	
	
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %glaze.r 
    date: 20-Jun-2010 
    version: 0.5.0 
    slim-name: 'glaze 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: GLAZE
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: WINDOW  v1.2.5
;--------------------------------------------------------------------------------

append slim/linked-libs 'window
append/only slim/linked-libs [


;--------
;-   MODULE CODE




;- slim/register/header
slim/register/header [

	; declare words so they stay bound locally to this module
	
	; sillica lib

	layout*: get in system/words 'layout
	
	

	;- LIBS
	epoxy: slim/open 'epoxy none
	
	!glob: to-color: none
	glob-lib: slim/open/expose 'glob none [!glob to-color]


	!plug: liquify*: content*: fill*: link*: unlink*: detach*: none
	liquid-lib: slim/open/expose 'liquid none [
		!plug 
		[liquify* liquify ] 
		[content* content] 
		[fill* fill] 
		[link* link] 
		[unlink* unlink] 
		[detach* detach] 
	]
	
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: none
	prim-bevel: prim-x: prim-label: none
	include: none
	sillica-lib: sl: slim/open/expose 'sillica none [
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		prim-bevel
		prim-x
		prim-label
		include
	]
	epoxy-lib: slim/open/expose 'epoxy none [!box-intersection]

	
	frame-lib: slim/open 'frame none
	viewport-lib: slim/open 'viewport none
	
	queue-event: clone-event: coordinates-to-offset: marble-at-coordinates: !event: dispatch: none
	event-lib: slim/open/expose 'event none [
		queue-event
		clone-event
		coordinates-to-offset
		marble-at-coordinates
		!event
		dispatch
	]
	

	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;
	item: none
	default-window-face: make face []
	foreach item next first default-window-face [
		set in default-window-face item none
	]
	
	default-window-face/color: white
	
	;--------------------------------------------------------
	;-   
	;- !WINDOW[ ]
	;
	; most of the window is the same as a frame.
	;
	; windows have extra event managing properties & rebol/view window stuff.
	!window: make viewport-lib/!viewport [
	
		;-    aspects[ ] 
		aspects: make aspects [
			;-        offset:
			offset: 100x100
			
			;-        label:
			label: any [sl/get-application-title "Untitled"]
			
			
			;-        block-input?:
			; when set to true, the fg-glob's backplane will fill the whole window and send 
			; a user specified message (usually specified from the marble style) down the queue.
			block-input?: none
			
			
			
			;-        color:
			color: theme-window-color
			
		]
		
		
		;-    material[ ] 
		; same as a frame
		material: make material [
			;-        title:
			title: none
			
		]
	
		
		;-    refresh-interval:
		;
		; milliseconds between refresh
		;
		; each window may have its own interval
		;
		; because of view's timer limitations, any value lower than 30 is actually
		; going to equate to ~ 30 since we only receive ~30 timer events per second from
		; view to begin with.
		; 
		; the default is pretty high (10 frames/second) , its a good idea to
		; lower it when:
		;    viewing large windows 
		;    frames contains many marbles
		;    many opened window at a time
		;    machine is too slow
		;
		; note that if nothing changes in the viewport, no actual refresh will occur.
		; a side-effect of liquid's lazyness.
		refresh-interval: 20
		
		;-    next-refresh:
		; an internal value managed by glass which acts as the trigger for the next
		; possible refresh.
		;
		; this is managed by the core-glass-handler
		;
		; discovered that the time ticks can go to negative values (basically a side-effect when it goes beyond 31 bits)
		next-refresh: -1 * power 2 31
		
		
		;-    auto-silence?:
		; if true, the window's stream automatically disables 
		; refresh of a window when it is deactivated.
		;
		; this means only one window will actively refresh.
		auto-silence?: true
		
		
		
		;-    layout-method:
		; the window is a column by default, edit before wrapping a frame.
		layout-method: 'column
		
		
		;-    view-face:
		; stores the face which is added to screen face
		view-face: none
		
		
		;-    stream:
		; stores the input stream processors.
		;
		; this is a simple block containing functions which are executed in sequence, which are 
		; allowed to interfere with the events generated for that window.
		;
		; when events first come in, they are converted to an !event.  This object is then
		; used within GLASS instead of the view event!.
		stream: none
		
		
		;-    backplug:
		; a plug which connects to our glob's layer 0 (the backplane layer).
		;
		; the backplane is used to very quickly determine what face is under the mouse.
		;
		; only the top most glob is available, but the shape of the glob's backplane needs not be
		; the same as the visual layers... 
		;
		; this means that you can very easily disable a marble's mouse interaction
		; just by leaving its backplane draw block empty.
		;
		backplug: none
		
		
		;-    backplane:
		; rendered image of the backplug
		backplane: none
		
		
		;-    overlay:
		; globs which are draw over all else, this ignores clipping.
		; they are used to show popups, menus, etc.
		;
		; when the overlay is visible, the window may block input to all other globs,
		; and will trigger an event of your choice when bg is clicked.
		;
		; queuing a 'REMOVE-OVERLAY message, removes the overlay from the display and
		; disables the input blocker
		;
		; this is a liquified glob which is compatible with glass, when the overlay is displayed.
		; otherwise its none.
		overlay: none
		
		
		
		;-    triggered-events:
		;
		; this block is responsible for storing pre-defined event which are triggered
		; when events happen relative to the window.
		;
		; for now only mouse down really makes sense.
		;
		; these events are queued by the trigger-events() function.
		;
		; note that not all events are managed by trigger-event right now... that might change.
		;
		triggered-events: compose/deep [
			; under normal circumstances these are triggered (queued)
			normal [
				pointer-press [
					(
					make !event [
						action: 'unfocus
					]
					)
				]
			]
			
			; when an overlay is being used and the input-blocker is enabled, these events are
			; sent instead.
			;
			; these events change often, since overlay events usually
			; are set by the code generating the overlay itself.
			;
			; event/viewport:  will be set by trigger-events()
			overlay [
				pointer-press [
					(
					make !event [
						action: 'remove-overlay
					]
					)
				]
			]
		
		]
		
		
		
		
		
		
		;-    FUNCTIONS
		; since the number of windows is limited, and it's a rather high-level
		; marble, we add the various window control functions
		; in the plug directly, to make it easier to use.
		
		;-----------------
		;-    display()
		; make the window visible on the screen.
		;-----------------
		display: func [
			/center "centers the window in screen"
			/local screen
		][
			vin [{show()}]
			unless visible? [
				screen: system/view/screen-face
				append system/view/screen-face/pane view-face
				view-face/size: content* material/dimension

				view-face/text: any [
					content* self/aspects/label
		            all [system/script/header system/script/title]
		            view-face/text
		            copy ""
		        ]

				vprint ["offset: " content* aspects/offset]
				if center [
					fill* aspects/offset (screen/size - view-face/size / 2)
				]
				view-face/offset: content* aspects/offset
				view-face/rate: 1 ; forces timer events in wake-event
				view-face/options: [resize]
				show screen
			]
			vout
		]
		
		
		;-----------------
		;-    hide()
		;-----------------
		hide: func [
			
		][
			vin [{hide()}]
			if visible? [
				remove find system/view/screen-face/pane view-face
				show system/view/screen-face
			]
			vout
		]
		
		
		
		
		
		;-----------------
		;-    visible?()
		;-----------------
		visible?: func [][
			; always returns logic value
			not not find system/view/screen-face/pane view-face
		]
		
		
		;-----------------
		;-    actions[]
		;-----------------
		actions: context [
			i: 0
		
			;-----------------
			;-        close-window()
			;
			; note: the return value is used as the confirmation to close the window.
			;       so returning none, prevents the window from closing.
			;-----------------
			close-window: func [
				event
			][
				true
			]
		]
		
		
		
		;-    valve []
		valve: make valve [
			;-        type:
			type: '!window


			;-        style-name:
			style-name: 'window
			

			;-        fg-glob-class:
			; class used to allocate and link a glob drawn IN FRONT OF the marble collection
			;
			; we use this to create an input blocker.
			fg-glob-class: make !glob [
				valve: make valve [
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup  these will be stored within the instance under input
						;position !pair (random 200x200)
						;dimension !pair (300x300)
						;color !color
						;frame-color  !color (random white)
						;clip-region !block ([0x0 1000x1000])
						;parent-clip-region !block ([0x0 1000x1000])
						block-input? !any (false)
						dimension !pair
					]
					
					;-            glob/gel-spec:
					gel-spec: [
						; block inputs
						block-input? dimension
						[
							(
							either (data/block-input?=) [
								compose [
									pen none 
									fill-pen (to-color gel/glob/marble/sid)
									box (0x0) (data/dimension= )
								]
							][
								; nothing to add to block
								[]
							]
							)
						]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						block-input? dimension
						[
							; here we restore our parent's clip region  :-)
							;clip (data/parent-clip-region=)
							
							;fill-pen none
							;pen (data/color=) red
							;line-pattern 10 10
							;box (vprint ["CLIP REGION:" mold data/clip-region= ] data/clip-region= )
							;(prim-bevel data/position= data/dimension=  white * .75 0.2 3)
							;(prim-X data/position= data/dimension=  (data/color= * 1.1) 10)
			
							(
								;print "WINDOW BLOCKED:"
							either (data/block-input?=) [
								compose [
									pen none 
									; dim interface, to indicate blocked input
									fill-pen (0.0.0.200) 
									box (0x0) (data/dimension= )
								]
							][
								; nothing to add to block
								[]
							]
							)
						]
						
						; controls layer
						;[]
						
						
					]
				]
			]

			;-        bg-glob-class:
			; class used to allocate and link a glob drawn BEHIND ALL OTHER marbles
			;
			; we use this to detect ckiking on the bg of the window.
			;
			; when this glob is selected, the window event handler will have special events
			; triggered.
			bg-glob-class: make !glob [
				valve: make valve [
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup  these will be stored within the instance under input
						;position !pair (random 200x200)
						;dimension !pair (300x300)
						;color !color
						;frame-color  !color (random white)
						;clip-region !block ([0x0 1000x1000])
						;parent-clip-region !block ([0x0 1000x1000])
						;block-input? !any (false)
						color !color
						dimension !pair
					]
					
					;-            glob/gel-spec:
					gel-spec: [
						; block inputs
						dimension
						[
							pen none 
							fill-pen (to-color gel/glob/marble/sid)
							box (0x0) (data/dimension= )
						]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						color dimension
						[
							pen none
							fill-pen (data/color=)
							box 0x0 (data/dimension= )
						]
						
						; controls layer
						;[]
						
						
					]
				]
			]

			
			
			;-----------------
			;-        detect-marble()
			;
			; returns the marble at specified coordinates for given window
			;
			; if the backplane layer has changed, it refreshes the backplane image.
			;
			; note that because the backplane layer usually only connects to the least 
			; materials and aspects it needs, it rarely ever changes, except when the layout
			; changes.
			;
			; also, because the backplane is only rendered when mouse interaction is required,
			; things like scrolling will not cause it to refresh automatically like the main layer would.
			;-----------------
			detect-marble: func [
				window [object!] 
				coordinates [pair!]
				/local size marble blk
			][
				;vin [{detect-marble()}]
				marble: none
				
				; is backplane up to date?
				if window/backplug/dirty? [
					;vprint "we must redraw backplane"
					
					; make sure we don't rely on an out of date backplane, and correctly trap any errors
					; which might occur while trying to rebuild it.
					window/backplane: none
					
					
					;-           render backplane
					if all [
						pair? size: content* window/material/dimension
						block? blk: content* window/backplug
					][
						;print "...................> Redraw-backplane"
						;prin "!"
						;vprint "dependencies are ok"
						;v?? size
						;v?? blk 
						;prin "-"
						;redraw backplane
						window/backplane: draw max size 2x2 compose [pen none fill-pen (white) box 0x0 (size) (blk)]
					]
				]
				
				if image? window/backplane [
					;vprint "backplane image exists"
					; make sure coordinates are within backplane bounds
					
					coordinates: min window/backplane/size coordinates
					;v?? coordinates
					
					; low-level image to plug 
					marble: marble-at-coordinates window/backplane coordinates
					
					;if marble[vprobe marble/sid]
				]
				;vout
				
				; this can be none or a pointer to the marble
				marble
			]
			
			
			;-----------------
			;-        collect()
			;-----------------
			collect: func [
				glob [object!]
			][
				vin [{collect()}]
				
				vout
			]
			

			;-----------------
			;-        trigger-events()
			;-----------------
			trigger-events: func [
				window [object!]
				event [object!]
				mode [word!]
				/local
			][
				vin [{trigger-events()}]
				if mode: select window/triggered-events mode [
					if mode: select mode event/action [
						foreach evt mode [
							queue-event clone-event/with evt [
								viewport: event/viewport 
								coordinates: event/coordinates 
								view-window: event/view-window
							]
						]
					]
				]
				
				vout
			]
			
			
			;-----------------
			;-        set-overlay-trigger()
			;
			; a handy function which resolves various trigger setups.
			;
			; the word triggers basically act as often-used predefined operations
			; which can be asked for instead of built manually.
			;-----------------
			set-overlay-trigger: func [
				window [object!] "the window MARBLE, not the view-face"
				trigger [object! none! word! block!]
			][
				vin [{set-overlay-trigger()}]
				switch type?/word trigger [
					object! [
					]
					
					none! [
						clear window/triggered-events/overlay/pointer-press
					]
					
					word! [
						switch/default trigger [
							; the default action
							; simply streams a remove-overlay event. 
							remove [
								window/triggered-events/overlay/pointer-press: reduce [
									make !event [
										action: 'remove-overlay
									]
								]
							]
							ignore [
								window/triggered-events/overlay/pointer-press: none 
								reduce [
;									make !event [
;										action: 'remove-overlay
;									]
								]
							]
						][
							; this is an error, because its a programming error, which must be dealt with
							; at development time.
							;
							; there is no reason to fallback to anything, since this means the programmer
							; isn't aware of the api and issued an invalid event.
							to-error "unknown trigger preset specified in set-overlay-trigger()"
						]
					]
					
					block! [
						; <TO DO> make sure block contains only events
						change head clear window/triggered-events/overlay/pointer-press event/trigger
						
					]
					
					
				]
				
				vprint "input-blocker trigger was set"
				vout
			]
			
			
			
			;-----------------
			;-        materialize()
			;-----------------
			materialize: func [
				win [object!]
			][
				vin [{materialize()}]
				
				win/material/title: liquify*/link process*/with 'window-title [window][
					if window: plug/window/view-face [
						window/text: pick data 1
						window/changes:  [text]
						show window
						window: plug: data: none
					]
				] [
					stainless?: true ; always update when dirty.
					window: win
				] win/aspects/label
				
				vout
			]
			
			
			
		

			;-----------------
			;-        setup-style()
			;-----------------
			setup-style: func [
				window
			][
				vin [{glass/!} uppercase to-string window/valve/style-name {[} window/sid {]/setup-style()}]
				vprint "SETTING UP WINDOW!"
				; we setup the face, so it links back to the !window (which is a viewport)
				window/view-face: make default-window-face [viewport: window]
				
				; allocate space for the viewport stream
				window/stream: copy []
				
				; create a generic handle to our glob's internal backplane (layer 1)
				window/backplug: liquify* epoxy/!merge
				
				;-        handler context[]
				context copy/deep [
				
					;-            hovered-marble:
					; what marble is currently hovered? 
					;
					; this stores the marble which generated the 'START-HOVER event (if any).
					hovered-marble: none
					
					
					;-            selected-marble:
					; what marble is currently selected?
					;
					; this stores the marble which generated the 'SELECT event (if any).
					selected-marble: none
					
					
				
					; add viewport handlers!
					vprint "adding refresh handler"
					event-lib/handle-stream/within 'window-handler 
						;-             window event handler
						; note, if we return an event, we intend for the streaming to continue
						; returning none or false will consume the event and this event is considered
						; completely managed.
						;
						; as usual, we may modify or even allocate a new event, and even queue new ones!
						func [
							event [object!]
							/local window marble qevent  wglob oglob 
						][
							vprint "WINDOW HANDLER"
							window: event/viewport
							
							vprint event/action
							switch/default event/action [
								;----------------------------------
								;-                  -pointer-move
								POINTER-MOVE [
									;vprint "------------------->hovering mouse!"
									;vprint event/coordinates
									marble: detect-marble window event/coordinates
									either selected-marble [
										;vprint "SWIPE?"
										; enter swipe mode
										event/marble: selected-marble
										event/offset: coordinates-to-offset selected-marble event/coordinates

										either same? selected-marble marble [
											event/action: 'SWIPE
										][
											; enables temporary drag & drop solution
											event: make event [drag-drop-candidate: marble]
											event/action: 'DROP?
										]
										event
									][
										; enter hover mode
										either same? hovered-marble marble [
											;if marble/handle-hover [
												event/action: 'HOVER
												event/marble: hovered-marble
												if event/marble [
													event/offset: coordinates-to-offset hovered-marble event/coordinates
												]
												; don't consume event.
												event
											;]
										][
											if hovered-marble [
												qevent: clone-event event
												qevent/action: 'END-HOVER
												qevent/marble: hovered-marble
												qevent/offset: coordinates-to-offset hovered-marble event/coordinates
												
												; we cause an event to be triggered right now.
												; our event handling is halted, until that terminates.
												;
												; when the dispatched event is done, the next part of hovering is
												; done, which might cause the original event to become a 'START-HOVER
												; event and be handled AFTER the dispatched event!
												dispatch qevent
											]
											if marble [
												event/action: 'START-HOVER
												event/marble: marble
												event/offset: coordinates-to-offset marble event/coordinates
											]
											; rememeber new marble (or lack of)
											hovered-marble: marble
											marble: none
											event
										]
									]
								]
								
								
								;----------------------------------
								;-                  -scroll-line
								; generate a scrollwheel event .
								; 
								; its cool that we can queue these and implement our own scrolling based on
								; other events... like swiped release, which slowly nudges a value
								; until the end is reached.  :-)
								;
								SCROLL-LINE [
									;vprint "SCROLL-LINE"
									if marble: detect-marble window event/coordinates [
									;	vprint "MARBLE UNDER CURSOR"
										event/marble: marble
										event/offset: coordinates-to-offset marble event/coordinates
									]
									event/action: 'SCROLL
									queue-event event
									
									; we consume the event since we requeued it.
									; the core handler might want to react to scrolling over a specific marble
									none
								]
								
								
								;----------------------------------
								;-                  -refresh
								REFRESH [
									vprint "------------------->Refresh!"
									;ask "!!"
									wglob: oglob: none
									if any [
										window/glob/dirty?
										all [
											window/overlay
											window/overlay/dirty?
										]
									][
										if sl/debug-mode? > 0 [
											prin ">"
										]
										; get new draw block(s) from our glob(s).
										wglob: content* window/glob
										oglob: all [object? window/overlay content* window/overlay] ; can be none
										
										
										either oglob [
											window/view-face/effect: reduce ['draw  wglob 'draw oglob]
										][
											window/view-face/effect: reduce ['draw  wglob]
										]
										;-----------------
										; saves out the complete draw block when problems occur,
										; very helpfull to cure AGG or draw glitches.
										;
										; the debug-mode? is set in sillica.
										;
										; a few things will trigger when debug-mode is set.
										if sl/debug-mode? > 2[	
											prin "->"
											save join glass-debug-dir %draw-blk.r window/view-face/effect
										]
										
										
										show window/view-face
									]
									none
								]
								
								
								;----------------------------------
								;-                  -pointer-press
								POINTER-PRESS [
									vprint "------------------->Moused button pressed!"
									vprint event/coordinates
									if object? marble: detect-marble window event/coordinates [
									
										; are these messages for ME?
										either same? marble window [
											vprint "========================================="
											vprint "             window bg clicked"
											vprint "========================================="
											selected-marble: window
											trigger-mode: either content* window/aspects/block-input? ['overlay]['normal]
											
											trigger-events window event trigger-mode
											
											;rectify the up/down symmetry
											event/action: 'SELECT
											event/marble: marble
											event/offset: event/coordinates
											queue-event event
											none
										][
											selected-marble: marble
											event/marble: marble
											event/offset: coordinates-to-offset selected-marble event/coordinates
											event/action: 'SELECT
											event
										]
									]
								]
								
								;----------------------------------
								;-                  -pointer-release
								POINTER-RELEASE [
									vprint "------------------->Moused button released!"
									vprint event/coordinates
									marble: detect-marble window event/coordinates 
									; are these messages for a marble or the window?
									either all [
										selected-marble
										not same? selected-marble window
									][
										;---------
										; pointer was released from a marble selection
										event/offset: coordinates-to-offset selected-marble event/coordinates
										event/marble: selected-marble
										either marble <> selected-marble [
											; give another marble the chance to refresh if the mouse is over it.
											dispatch clone-event/with event [
												action: 'END-HOVER 
											]
											dispatch qevent: clone-event/with event compose [
												action: 'START-HOVER 
												marble: (marble)
												offset: (if marble [coordinates-to-offset marble event/coordinates])
											]
											
											either marble [
												;--------
												; we released mouse over another marble
												;--------
												
												; expand event
												event: make event [
													dropped-on: marble
													dropped-offset: qevent/offset ; saves processing
												]
												
												; released on another marble
												event/action: 'DROP
												
											][
												; released on bg
												event/action: 'NO-DROP
											]
										][
											;--------
											; we released mouse over ourself
											;--------
											
											event/action: 'RELEASE
										]
									][
										;---------
										; pointer was released from a window selection
										vprint "========================================="
										vprint "             window released"
										vprint "========================================="
										trigger-events window event 'normal
										event: none
									]
									selected-marble: none
									event
								]
								
								;----------------------------------
								;-                  -add-overlay
								;
								; <TO DO>: support multiple overlays
								;
								; this tells the window to do its overlay handling stuff.
								ADD-OVERLAY [
									vprint "ADDING AN overlay to WINDOW: "
									if event/view-window [
										vprint  [event/view-window/text]
									]
									
									either all [
										in event 'frame   ; the marble to display (should be a frame subclass)
										in event 'trigger ; events put in triggered events
										object? event/frame
										;event/marble  ; who initiated the overlay
									][
										unless none? event/trigger [
											fill* window/aspects/block-input? true
										]
										set-overlay-trigger window event/trigger
										
										; set overlay
										window/overlay: event/frame/glob
										; link overlay back plane
										link* window/backplug event/frame/glob/layers/1
										none
									][
										event
									]
								]

								;----------------------------------
								;-                  -remove-overlay
								; this tells the window to do its overlay handling stuff.
								REMOVE-OVERLAY [
									vprint "Make sure the input blocker is removed"
									if content* window/aspects/block-input? [
										fill* window/aspects/block-input? false
									]
									if window/overlay [
										unlink*/only window/backplug window/overlay/layers/1
										window/overlay: none
									]
									
									
									event
								]

								;----------------------------------
								;-                  -window-position
								WINDOW-POSITION [
									vprint "------------------->Window positioned!"
									vprint event/coordinates
									fill* window/aspects/offset event/coordinates
									
									; below is not currently required and because we receive hundreds of events,
									; it because a HUGE CPU hog.
									;
									; if you need to respond to window moves, link to window/aspects/offset.
									;show event/view-window
									none
								]
								
								;----------------------------------
								;-                  -close-window
								CLOSE-WINDOW [
									vprint "------------------->Window closed!"
									vprint window/aspects/label
									; the result of this action determines if we should close the window
									event/marble: window
									if do-action event [
										window/hide
									]
									none
								]


								
								;----------------------------------
								;-                  -window-resized
								WINDOW-RESIZED [
									vprint "------------------->Window Resized!"
									vprint event/coordinates
									
									; we consume resize events.
									fill* window/material/dimension event/coordinates
									window/view-face/effect: [draw []] 
									show window/view-face
									window/view-face/effect: reduce ['draw content* window/glob]
									show window/view-face
									;window/view-face/effect: reduce ['draw  copy/deep content* window/glob]
									;show window/view-face
									
									none
								]

							
								DEACTIVATE-WINDOW! [
									; tells window to activate a window.. this isn't an event generate by view, 
									; but is a constructed event.  
									;
									; its actually a command, so we use the ! at the end of the event name (just for style).
									event/view-window/changes: [deactivate]
									show event/view-window
									none
								]
							
							
								ACTIVATE-WINDOW! [
									; tells window to activate a window.. this isn't an event generate by view, 
									; but is a constructed event.  
									;
									; its actually a command, so we use the ! at the end of the event name (just for style).
									event/view-window/changes: [activate]
									show event/view-window
									none
								]
							
								RESIZE-WINDOW! [
									; tells window to resize  window.. this isn't an event generate by view, 
									; but is a constructed event.  
									;
									; its actually a command, so we use the ! at the end of the event name (just for style).
									;
									; note that as a side-effect of this "event" a real 'resize event will be triggered by view.
									event/view-window/size: event/coordinates 
									event/view-window/changes: [size]
									show event/view-window
									none
								]
								
								MOVE-WINDOW! [
									; tells stream to change window offset.. this isn't an event generate by view, 
									; but is a constructed event.  
									;
									; its actually a command, so we use the ! at the end of the event name (just for style).
									;
									; note that as a side-effect of this "event" a real 'window-resize event will be triggered by view.
									event/view-window/offset: event/coordinates
									event/view-window/changes: [offset]
									show event/view-window
									none
								]
							
							
							][
								vprint ["Window Unhandled: " event/action]
								; leave for next handler
								event
							]
						] window
					
				] ; end of event handler context
				;ask "!!"
				vout
			]
			
			;-----------------
			;-        fasten()
			;
			; we keep the core GLASS frame setup, but tweak it to match !window specifics
			;-----------------
			fasten: func [
				window
			][
				vin [{fasten()}]
				; our offset is a reflection of the actual window's screen position
				; so our position should not be related to it in any way
				unlink*/only window/material/position window/aspects/offset
				
				; the internal position of a window's frame is always 0x0
				; this could eventually be pluged to scroll bars
				fill* window/material/position 0x0
				
				; connect our backplane plug to the glob's backplane layer directly
				link*/reset window/backplug window/glob/layers/1
				vout
			]
			
			
		
		]
	]
]


;--------
;-   SLIM HEADER
[
    title: "window" 
    author: "Maxim Olivier-Adlhoch" 
    file: %window.r 
    date: 14-Jul-2010 
    version: 1.2.5 
    slim-name: 'window 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: WINDOW
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: VIEWPORT  v0.8.0
;--------------------------------------------------------------------------------

append slim/linked-libs 'viewport
append/only slim/linked-libs [


;--------
;-   MODULE CODE



;- slim/register/header
slim/register/header [

	; declare words so they stay bound locally to this module
	!plug: liquify*: !glob: content*: fill*: link*: unlink*: none
	
	; sillica lib
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: none
	prim-bevel: prim-x: prim-label: none
	include: none

	layout*: get in system/words 'layout
	
	

	;- LIBS
	glob-lib: slim/open/expose 'glob none [!glob]
	liquid-lib: slim/open/expose 'liquid none [
		!plug 
		[liquify* liquify ] 
		[content* content] 
		[fill* fill] 
		[link* link] 
		[unlink* unlink] 
		[detach* detach] 
	]
	sillica-lib: slim/open/expose 'sillica none [
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		prim-bevel
		prim-x
		prim-label
		include
	]
	epoxy-lib: slim/open/expose 'epoxy none [!box-intersection]

	
	frame-lib: slim/open 'frame none
	

	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;

	
	
	;--------------------------------------------------------
	;-   
	;- !VIEWPORT[ ]
	;
	; The view is the handle you have on a gui.  its like an OpenGL viewport, where you embed
	; graphics into an external graphic/UI container.
	;
	; things like coordinates are mapped to-from the the container to the view's internal values.
	;
	; most of the view is the same as a frame.
	;
	; views basically are the event-aware wrappers which allow the internals to react to
	; mouse and keyboard.
	;
	; note that !viewport and any derivative can ONLY be used as wrappers.  its the point of having them.
	!viewport: make frame-lib/!frame [
	
		;-    aspects[ ] same as a frame
		aspects: make aspects [ ]
		
		
		;-    material[ ] same as a frame
		material: make material []
	
		
		
		;-    layout-method:
		; the view is a column by default, but this can be changed after
		layout-method: 'column
		
		
		;-    view-face:
		; stores the face in which the view is displayed (remember, this may be a window face!)
		view-face: none
		
		
		;-    stream:
		;
		; stores the input stream handlers.
		;
		; this is a simple block containing functions which are executed in sequence.
		; These are allowed to interfere with the events generated for that view.
		;
		; when events first come in, they are converted to an !event.  This object is then
		; used within GLASS instead of the view event!.
		stream: none
		
		
		
		;-    valve []
		valve: make valve [

			type: '!viewport


			;-        style-name:
			style-name: 'view


			;-        is-viewport?:
			; tells the system that this marble can be used as a viewport and has
			; a face, ready to be linked within view somehow.
			is-viewport?: true
			
			

		
		]
	]
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %viewport.r 
    date: 20-Jun-2010 
    version: 0.8.0 
    slim-name: 'viewport 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: VIEWPORT
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: STYLE-FIELD  v0.8.0
;--------------------------------------------------------------------------------

append slim/linked-libs 'style-field
append/only slim/linked-libs [


;--------
;-   MODULE CODE



slim/register/header [
	; declare words so they stay bound locally to this module

	layout*: get in system/words 'layout
	
	

	;- LIBS
	!glob: to-color: none
	glob-lib: slim/open/expose 'glob none [!glob to-color]
	
	marble-lib: slim/open 'marble none
	
	
	!plug: liquify*: content*: fill*: link*: unlink*: none
	liquid-lib: slim/open/expose 'liquid none [
		!plug 
		[liquify* liquify ] 
		[content* content] 
		[fill* fill] 
		[link* link] 
		[unlink* unlink] 
		[dirty* dirty]
	]
	
	
	prim-bevel: prim-x: prim-label: prim-glass: none
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: none
	top-half: bottom-half: none
	sillica-lib: slim/open/expose 'sillica none [
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		prim-bevel
		prim-x
		prim-label
		prim-glass
		top-half
		bottom-half
	]
	epoxy-lib: slim/open/expose 'epoxy none [!box-intersection]
	event-lib: slim/open 'event none

	

	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;

	;--------------------------------------------------------
	;-   
	;- !FIELD[ ]
	!field: make marble-lib/!marble [
	
		;-    Aspects[ ]
		aspects: make aspects [
			;-        cursor-index:
			; this is the index of the cursor within the label
			cursor-index: 2
			
			
			;-        cursor-highlight:
			cursor-highlight: none
			
			
			;-        label-index:
			; what is the first visible character in the field?
			; this is used by the field to make sure that the cursor is always visible,
			; otherwise, it will run off out of view.
			label-index: 1

			
			;-        focused?:
			focused?: false
			
			
			;-        label:
			label: ""
			
			
			;-        color:
			color: black
			
		]

		;-    label-backup:
		; when focus occurs, store our label here
		; if escaped, we go back to it.
		label-backup: none
		

		
		;-    Material[]
		material: make material []
		
		
		;-    valve[ ]
		valve: make valve [
		
			type: '!marble
		
			;-        style-name:
			; used as a label for debugging and node browsing.
			style-name: 'field  
			
			
			;-        field-font:
			; font used by the gel, which is MONOSPACE for now.
			field-font: theme-field-font
			
			;-        font-width:
			; used temporarily to calculate index 
			font-width: theme-field-char-width
			
			
			;-        cursor-x:
			cursor-x: 0
			highlight-x: 0
			
			hbox-s: 0x0
			hbox-e: 0x0
			
			clr1: none
			clr2: none
			clr3: none
			
			d: none ; dimension
			p: none ; position
			e: none ; box end (dimension + position)
			f?: none ; focused?
			c: none ; center
			
			highlight-color: 0.0.0.50
			
			
			;-        glob-class:
			; defines the glob which will be built by each marble instance.
			;   glob-class/marble  is added automatically by setup.
			glob-class: make !glob [
				valve: make valve [
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup these will be stored within glob/input
						position !pair (random 200x200)
						dimension !pair (100x30)
						color !color  (random white)
						label !string ("")
						cursor-index !integer
						cursor-highlight !any ; maybe integer or none
						focused? !bool
						hover? !bool
						label-index !integer
					]
					
					;-            glob/gel-spec:
					; different AGG draw blocks to use, one per layer.
					; these are bound and composed relative to the input being sent to glob at process-time.
					gel-spec: [
						; event backplane
						position dimension 
						[
							line-width 1 
							pen none 
							fill-pen (to-color gel/glob/marble/sid) 
							box (data/position=) (data/position= + data/dimension= - 1x1)
						]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						position dimension color label hover? focused? cursor-index cursor-highlight label-index
						[
							(
								;print "!!!"
								d: data/dimension=
								p: data/position=
								e: d + p - 1x1
								c: d / 2 + p - 1x1
								f?: data/focused?=
								vrange: visible-range gel/glob/marble 
								cursor-x: ( data/cursor-index= - data/label-index= + 1 * font-width) * 1x0
								if data/cursor-highlight= [
									highlight-x: ( data/cursor-highlight= + 1 - data/label-index= * font-width) * 1x0
									hbox-s: min (max p + 0x1 (cursor-x + p + -3x0)) e + 0x-1
									hbox-e: min (max p + 0x3 (p + highlight-x + (0x1 * d) - 3x1)) e - 0x1
								]
							 []
							)
							line-width 1
							pen none
							
							; bg
							fill-pen linear (p) 1 (d/y) 90 1 1 
;								(either f?  [wheat * .95 + 20.20.20][white * .98]) 
;								(either f?  [wheat * .95 + 20.20.20][white * .98]) 
;								(either f? [wheat + 20.20.20][white]) 
								(white * .98) 
								(white * .98) 
								(white) 
							box (p) (e) 3
							
;							(
;								either data/focused?= [
;									compose [
;										fill-pen (theme-color + 0.0.0.240)
;										box (p) (e) 3
;									]
;								][[]]
;							)
							

							; top shadow
							fill-pen linear (p + 0x1) 1 (4) 90 1 1 
								(0.0.0.150) 
								(0.0.0.220) 
								(0.0.0.240) 
								(0.0.0.255 )
							box (p) (e) 3

							
							
							pen none
							(
								either all [data/cursor-highlight= data/focused?=] [
									compose [
										fill-pen 255.255.255.200
										box (hbox-s) (hbox-e) 3
									]
								][[]]
							)
							
							
							
							fill-pen none
							
							; basic text
							line-width 1
							(
								 ;vrange: [1 10]
								 ;?? vrange
								
								prim-label copy/part at data/label= vrange/1 at data/label= (vrange/2 + 1) p + 4x1 d data/color= field-font 'west
							)
							
							(	
								either f?  [ 
									compose [
										
										
											; highlight box
										(
										 	compose either data/cursor-highlight= [
										 		prim-glass hbox-s hbox-e theme-color 190
										 		
;												[
;													line-width 1
;													
;													
;													fill-pen linear (p) 1 (d/y) 90 1 1 ( highlight-color * 0.6 + 128.128.128.150) ( highlight-color + 0.0.0.150) (highlight-color * 0.5 + 0.0.0.150)
;													pen (black + 0.0.0.150)
;													box  ( hbox-s ) (hbox-e )
;													
;													
;													; shine
;													pen none
;													fill-pen (255.255.255.175)
;													box ( top-half  ( hbox-s + 0x2) (hbox-e - hbox-s ) )
;													
;													; shadow
;													fill-pen linear (p + 0x15) 1 10 90 1 1 
;														0.0.0.255
;														0.0.0.200
;														0.0.0.150
;													box ( hbox-s + 0x15) (hbox-e )
;												]
											][
												[]
											]
										)
										
										; add cursor
										(
										 	compose either data/cursor-highlight= [
										 		[
													pen (red)
													fill-pen none
													line-width 1
													line ( cursor-x + p - 2x0)
													     (p + cursor-x + (0x1 * d) - 2x2)
												]
											][
												[
													pen (red)
													fill-pen none
													line-width 2
													line ( cursor-x + data/position= - 3x0)
													     (data/position= + cursor-x + (0x1 * data/dimension=) - 3x2)
												]
											]
										)
									]
								][
									[]
								]
							)


							


							; draw edge highlight?
							( 
								;print "--------->" 
								compose either any [data/hover?= f? ][
									[
										line-width 2
										fill-pen none
										pen (theme-color + 0.0.0.175)
										box (data/position= + 1x1) (data/position= + data/dimension= - 2x2) 3
										pen white
										fill-pen none
										line-width 1
										box (data/position=) (data/position= + data/dimension= - 1x1) 3
									]
								][[
									; simple gray border
									pen theme-border-color
									fill-pen none
									line-width 1
									box (data/position=) (data/position= + data/dimension= - 1x1) 3
								]]
							)
							
							;clip 0x0 10000x10000

						]
							
						; controls layer
						;[]
						
						; overlay layer
						; like the bg, it may switched off, so don't depend on it.
						;[]
					]
				]
			]
			
			
			;-----------------
			;-        set-cursor-from-coordinates()
			;-----------------
			set-cursor-from-coordinates: func [
				marble [object!]
				offset [pair!]
				highlight? [logic! none!]
			][
				vin [{set-cursor-from-coordinates()}]
				i: offset/x
				i: to-integer (i + 6 / font-width)
				i: -1 + i + any [content* marble/aspects/label-index 1]
				
				move-cursor marble i highlight?
				vout
			]
			
			




			;-----------------
			;-        cut-highlight()
			;-----------------
			cut-highlight: func [
				marble
				/only "does not default to whole string if nothing is highlighted"
				/local h i t s 
			][
				vin [{cut-highlight()}]
				i: content* marble/aspects/cursor-index
				h: content* marble/aspects/cursor-highlight
				t: content* marble/aspects/label
				if h [
					either only [
						s: get-highlight marble/only
					][
						s: get-highlight marble
					]
					
					any [
						all [  h   i < h  (vprint "CUT FROM INDEX" 1) remove/part at t i at t h]
						all [  h  (vprint "CUT FROM INDEX" 1) remove/part at t h at t i]
						all [not only  (vprint "CUT FROM ALL" 1) t]
					]
					
					fill* marble/aspects/cursor-highlight none
					
					move-cursor marble min i h false
				]
				vout
				s
			]
			
			
			
			
			;-----------------
			;-        move-cursor()
			;-----------------
			move-cursor: func [
				marble
				to [integer!]
				highlight? [logic! none!] "none means, leave it as-is"
				/local vrange new-index range
			][
				vin [{set-cursor()}]
				
				; force bounds
				to: normalize-cursor-index marble to
				
				; none means, leave it as-is
				unless none? highlight? [
					either highlight? [
						highlight marble
					][
						unhighlight marble
					]
				]
				; make sure the cursor doesn't move outside of field.
				vrange: visible-range marble
				;?? to
				;?? vrange
				if (to - 1) > (vrange/2 ) [
					range: vrange/2 - vrange/1
					;?? range
					new-index: to - range - 1
					;?? new-index
					fill* marble/aspects/label-index new-index
				]
				if to  < vrange/1 [
					fill* marble/aspects/label-index to
				]
				fill* marble/aspects/cursor-index to
				vout
			]
			
			
			;-----------------
			;-        visible-range()
			;-----------------
			visible-range: func [
				marble
				/local from to
			][
				vin [{visible-range()}]
				
				from: max 1 any [content* marble/aspects/label-index 1]
				to: -2 + from + to-integer (first (content* marble/material/dimension) / marble/valve/font-width)
				to: min to length? content* marble/aspects/label
				
				vout
				reduce [from to]
			]
			
			;-----------------
			;-        visible-length?()
			;-----------------
			visible-length?: func [
				marble
				/local vrange
			][
				vin [{visible-length?()}]
				vrange: visible-range marble
				
				
				;v?? vrange
				
				vout
				1 + vrange/2 - vrange/1
			]
			
			
			
			
			;-----------------
			;-        insert-content()
			;-----------------
			insert-content: func [
				marble
				data [string! integer! decimal! tuple! tag! issue! char!]
				/local i t
			][
				vin [{insert-text()}]
				; just in case
				cut-highlight marble
				
				data: switch/default type?/word data [
				 	string! [data ]
				 	char! [to-string data]
				][
					mold data
				]
				; fields may not contain other whitespaces than space.
				data: replace/all data "^/" " "
				data: replace/all data "^-" " "
				
				i: content* marble/aspects/cursor-index
				t: content* marble/aspects/label
				
				insert at t i data
				
				;dirty* marble/aspects/label
				move-cursor marble i + length? data false

				fill* marble/aspects/label t
				vout
			]
			
			
			
			
			;-----------------
			;-        highlight()
			;
			; by default, does nothing if field is already highlighted
			;-----------------
			highlight: func [
				marble
				/reset "reset cursor-highlight even if its already set"
			][
				vin [{highlight()}]
				if any [
					not content* marble/aspects/cursor-highlight
					reset
				][
					fill* marble/aspects/cursor-highlight content* marble/aspects/cursor-index
				]				
				vout
			]


			;-----------------
			;-        unhighlight()
			;-----------------
			unhighlight: func [
				marble
			][
				vin [{unhighlight()}]
				; don't propagate unhighlight if its already the case
				if content* marble/aspects/cursor-highlight [
					fill* marble/aspects/cursor-highlight none
				]
				vout
			]

			
			;-----------------
			;-        normalize-cursor-index()
			;-----------------
			normalize-cursor-index: func [
				marble [object!]
				index [integer!]
				;/local h l
			][
				min 1 + length? content* marble/aspects/label max 1 index
			]
			
			
			;-----------------
			;-        normalize-label-index()
			;-----------------
			normalize-label-index: func [
				marble [object!]
				index [integer!]
				;/local h l
			][
			
				; index = 1 > (length -  visible-length?)
				min 1 + ((length? content* marble/aspects/label) - visible-length? marble) max 1 index
			]
			
			
			;-----------------
			;-        set-label-index()
			;-----------------
			set-label-index: func [
				marble
				index [integer!]
			][
				vin [{set-label-index()}]
				index: normalize-label-index marble index
				if index <> any [content* marble/aspects/label-index 1] [
					fill* marble/aspects/label-index index
				]
				vout
			]
			
			
			
			
			;-----------------
			;-        set-highlight()
			;-----------------
			set-highlight: func [
				marble
				from [integer!]  "from is cursor-highlight"
				to [integer!] "to will become cursor"
			][
				vin [{set-highlight()}]
				
				from: normalize-cursor-index marble from
				to: normalize-cursor-index marble to
				
				fill* marble/aspects/cursor-highlight from
				fill* marble/aspects/cursor-index to
				vout
			]
			
			
			;-----------------
			;-        find-word()
			;-----------------
			find-word: func [
				marble
				start [integer!]
				/reverse
				/local aspects i t 
			][
				vin [{find-next-word()}]
				t: content* marble/aspects/label
				
				either reverse [
					i: start
					; skip spaces
					while [#" " = pick t i - 1] [
						i: i - 1
					]
					either t: find/reverse/tail at t i  " " [
						i: index? t
					][
						; if there is no space beyond cursor, go at head
						i: 1
					]			
				][
					either t: find/tail at t start  " " [
						i: index? t
						t: head t 
						; skip spaces
						while [#" " = pick t i] [
							i: i + 1
						]
					][
						; if ther is no space beyond cursor, go at end
						i: 10000000
					]			
				]
				vout
				i
			]
			
			
			;-----------------
			;-        highlight-word()
			;-----------------
			highlight-word: func [
				marble
				/local aspects i h t
			][
				vin [{highlight-word()}]
				
				highlight/reset marble
				
				i: content* marble/aspects/cursor-index
				h: i
				t: content* marble/aspects/label
				
				either #" " = pick t i [
					;-------
					; highlight spaces
					;-------
					either i >= h [
						; select spaces
						while [#" " = pick t i] [
							i: i + 1
						]
						while [#" " = pick t h - 1] [
							h: h - 1
						]
					][
						; select spaces
						while [#" " = pick t h] [
							h: h + 1
						]
						while [#" " = pick t i - 1] [
							i: i - 1
						]
					]
					
					set-highlight marble h i
					
				][
					;-------
					; highlight word
					;-------
					; we keep orientation of highlight!
					either i >= h [
						; select all but spaces
						while [all [pick t i #" " <> pick t i] ] [
							i: i + 1
						]
						while [all [pick t h #" " <> pick t h - 1] ] [
							h: h - 1
						]
					][
						; select all but spaces
						while [all [pick t h #" " <> pick t h]] [
							h: h + 1
						]
						while [all [pick t i #" " <> pick t i - 1] ] [
							i: i - 1
						]
					]
					set-highlight marble i h
				]
				
				
				
				vout
			]
			
			
			
			
			;-----------------
			;-        type()
			;
			; <TO DO> filter valid character types on event.
			;-----------------
			type: func [
				event
				/local aspects i t l k m h
				       fill?
			][
				vin [{type()}]
				aspects: event/marble/aspects
				vprint ["typing into : " content* aspects/label]
				vprobe event/key
				
				
				i: content* aspects/cursor-index
				t: content* aspects/label
				l: length? t
				k: event/key
				m: event/marble
				h: content* aspects/cursor-highlight
				
				vprint "========================================================================"
				vprint "========================================================================"
				vprint "========================================================================"
				vprint "========================================================================"
				fill?: switch/default k [
					; generate an unfocus
					escape [
						; we restore the previous text we had before the focus occured
						fill* aspects/label m/label-backup
						event-lib/queue-event event-lib/clone-event/with event [action: 'unfocus ]
						false
					]
					
					enter [
						; in a field, the enter event, just generates an unfocus
						event-lib/queue-event event-lib/clone-event/with event [action: 'unfocus ]
						false
					]
					
					erase-current [
						either h [
							cut-highlight m
						][
							if i <= l [
								remove at t i
							]
						]
						true
					]
					
					erase-previous [
						either h [
							cut-highlight m
						][
							if i > 1 [
								i: i - 1
								remove at t i
								fill* aspects/cursor-index i
							]
						]
						true
					]
					
					erase-all [
						unhighlight m
						cut-highlight m
						true
					]
					
					select-all [
						set-highlight m 1 100000
						false
					]
					
					move-right [
						move-cursor m i + 1 event/shift?
						false
					]
					
					move-left [
						move-cursor m i - 1 event/shift?
						false
					]
					
					move-to-begining-of-line [
						move-cursor m 1 event/shift?
						false
					]
					
					move-to-next-word move-up [
						i: find-word m i ; can return past tail !
						move-cursor m i event/shift?
						false
						
					]
					
					move-to-previous-word move-down [
						i: find-word/reverse m i ; can return past tail !
						move-cursor m i event/shift?
						false
					]
					
					move-to-end-of-line [
						move-cursor m l + 1 event/shift?
						false
					]
					
					cut [
						if t: cut-highlight m [
							write clipboard:// t
						]
						true
					]
					
					copy [
						write clipboard:// get-highlight event/marble
						fill* aspects/cursor-highlight none
						false
					]
					
					
					paste [
						; read returns none if clipboard doesn't contain plaintext
						if l: read clipboard:// [
							; just make sure we don't try to paste a 700MB file!
							if 1024 < length? l[
								l: copy/part l 1024
							]
							insert-content m l
						]
						true
					]
					
					
				][
					unless word? k [
						insert-content m k
					]
					true
				]
				vprint "notifying pipe"
				if fill? [
					fill* aspects/label t
				]

				;aspects/label/valve/notify aspects/label

				vout
				
			]
			
			;-----------------
			;-        get-highlight()
			; returns none if nothing is highlighted
			;-----------------
			get-highlight: func [
				marble
				/only "does not default to whole string if nothing is highlighted"
				/local h i t
			][
				i: content* marble/aspects/cursor-index
				h: content* marble/aspects/cursor-highlight
				t: content* marble/aspects/label
				any [
					all [  h   i < h   copy/part at t i at t h]
					all [  h   copy/part at t h at t i]
					all [not only t]
				]
			]
			
						

			
			
			;-----------------
			;-        ** field-handler() **
			;
			; this handler is used for testing purposes only. it is shared amongst all marbles, so its 
			; a good and memory efficient handler.
			;-----------------
			field-handler: func [
				event [object!]
				/local field i
			][
				vin [{HANDLE FIELD}]
				vprint event/action
				
				field: event/marble
				
				switch/default event/action [
					start-hover [
						fill* event/marble/aspects/hover? true
					]
					
					end-hover [
						fill* event/marble/aspects/hover? false
					]
					
					select [
						vprint event/coordinates
						vprint ["tick: " event/tick]
						vprint ["fast-clicks: "event/fast-clicks]
						vprint ["coordinates: " event/coordinates]
						either true = content* event/marble/aspects/focused? [
							set-cursor-from-coordinates event/marble event/offset event/shift?
							
							if event/fast-clicks [
								either event/fast-clicks > 1 [
									; higlight all on triple click
									set-highlight event/marble 1 2000000
								][
								; highlight word or space on double click
									highlight-word event/marble
								]
							]
						][
							event/action: 'focus
							; tell the system that WE want to be focused
							event-lib/queue-event event
						]
					]
					
					scroll [
						vprint "scrolling!"
						vprint content* field/aspects/label-index
						
						i: any [content* field/aspects/label-index 1]
						i: i + either event/direction = 'pull [ 1][-1]
						v?? i
						set-label-index field i
					]
					
					focused-scroll [
						; lets be lazy and requeue it as text-entry event!
						; then any cool side-effects are handled for free (ctrl + shift)
						;
						; note that 'text-entry action bypasses window and core key handlers.
						event-lib/queue-event compose [
							action: 'marble-text-entry
							view-window: (event/view-window)
							coordinates: (event/coordinates)
							marble: (event/marble)
							key: (either event/direction = 'pull [to-lit-word 'right][to-lit-word 'left])
							shift?: (event/shift?)
							control?: (event/control?)
						]
						
;						vprint "focused scrolling!"
;						vprint content* field/aspects/cursor-index
;						
;						i: any [content* field/aspects/cursor-index 1]
;						i: i + either event/direction = 'pull [ 1][-1]
;						v?? i
;						move-cursor field i event/control?
					]
					
					swipe drop? [
						set-cursor-from-coordinates event/marble event/offset true
					]
					
					focus [
						event/marble/label-backup: copy content* event/marble/aspects/label
						if pair? event/coordinates [
							set-cursor-from-coordinates event/marble event/offset false
						]
						fill* event/marble/aspects/focused? true
					]
					
					unfocus [
						event/marble/label-backup: none
						fill* event/marble/aspects/focused? false
					]
					
					text-entry marble-text-entry [
						type event
						dirty* event/marble/aspects/cursor-index
					]
				][
					vprint "IGNORED"
				]
				
				vout
				none
			]
			
			;-----------------
			;-        setup-style()
			;-----------------
			; a callback to extend anything in the marble AFTER Glass has finished with its own setup
			;
			; this is used by styles for their own custom data requirements.
			;
			; styles may also provide application setup hooks, but usually do so via extensions to the
			; the specification parser, using dialect()
			; 
			; some styles will also add default stream handlers (like viewports)
			;-----------------
			setup-style: func [
				marble
			][
				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/stylize()}]
				
				; just a quick stream handler for all marbles
				event-lib/handle-stream/within 'field-handler :field-handler marble
				vout
			]
		]
	]
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %style-field.r 
    date: 20-Jun-2010 
    version: 0.8.0 
    slim-name: 'style-field 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: STYLE-FIELD
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: STYLE-SCRIPT-EDITOR  v0.8.0
;--------------------------------------------------------------------------------

append slim/linked-libs 'style-script-editor
append/only slim/linked-libs [


;--------
;-   MODULE CODE



slim/register/header [
	; declare words so they stay bound locally to this module

	layout*: get in system/words 'layout
	
	

	;- LIBS
	!glob: to-color: none
	glob-lib: slim/open/expose 'glob none [!glob to-color]
	
	marble-lib: slim/open 'marble none
	
	
	!plug: liquify*: content*: fill*: link*: unlink*: notify*: none
	liquid-lib: slim/open/expose 'liquid none [
		!plug 
		[liquify* liquify ] 
		[content* content] 
		[notify* content] 
		[fill* fill] 
		[link* link] 
		[unlink* unlink] 
		[dirty* dirty]
		[bridge* bridge]
	]
	
	glue-lib: slim/open 'glue none
	
	
	prim-bevel: prim-x: prim-label: prim-glass: prim-text-area: none
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: none
	top-half: bottom-half: remove-duplicates: text-to-lines: swap-values: none
	sillica-lib: slim/open/expose 'sillica none [
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		prim-bevel
		prim-x
		prim-label
		prim-glass
		top-half
		bottom-half
		prim-text-area
		remove-duplicates
		text-to-lines
		shorter?
		shorten
		elongate
		swap-values
	]
	epoxy-lib: slim/open/expose 'epoxy none [!box-intersection]
	event-lib: slim/open 'event none

	


	;--------------------------------------------------------
	;-   
	;- !EDITOR[ ]
	!editor: make marble-lib/!marble [
	
	
		;-    stored-cursors:
		;
		; when we need to store the cursor positions for some reasons, we store them here.
		;
		; this is usually used when navigating the mouse up and down, so as to allow the cursors to go
		; back to their positions before changing lines, if intermediate lines where shorter.
		;
		; its also used by the swiper to remember what selections looked like when mouse was pressed.
		stored-cursors: none
		
	
	
		;-    Aspects[ ]
		aspects: make aspects [
			;        size:
			size: 200x100
			
			;        padding:
			;
			; edges to remove from editing area in pixels,
			; this includes visible edges.
			padding: 3x3
			
			;        color:
			; default text color
			color: black
			
			;        focused?:
			focused?: false
			
			;        font:
			font: theme-editor-font
			
			
			
			
			;-        cursor-index:
			; this is the index of the cursor within the label
			cursor-index: 2
			
			;-        cursor-highlight:
			cursor-highlight: none
			
			
			;-        top-off:
			; what is the first visible line in the editor line?
			; this is used by the editor to make sure that the cursor is always visible,
			; otherwise, it would run off out of view.
			top-off: 1
			
			
			;-        left-off:
			; what is the first visible column in the editor?
			left-off: 5
			
			
			;-        edit-options:
			; 
			; these are used to control how editing occurs (insert, overwrite, etc)
			edit-options: none
			
			
			;-        text:
			; 
			; this will be set to a special pipe client which merges the paragraphs
			; into a single string
			text: ""
			
			
			
			;-        key-words:
			; a set of words which will be displayed in an alternate color
			key-words: none
			
			
			
			;-        leading:
			; extra space between lines, can be negative.
			leading: 7
			
			
			;-        cursors:
			; a list of text cursors for the editor
			cursors: [ ]
			
			;-        selections:
			selections: [ ]
			
			
			;-        modes:
			; a block of words which holds optional modes for the editor
			;
			;   indented-new-line
			;   overwrite mode
			modes: none
			
			
		]


		
		;-    Material[]
		material: make material [
			;-        min-dimension:
			min-dimension: 200x100
			
			
			
			
			;-        fill-weight:
			fill-weight: 1x1
			
			;-        history:
			; stores undo/redo information
			; 
			; we store our history in a plug, just for fun.
			; it will be a bulk, which allows us to use bulk diagnostic nodes to
			; display or act on the history.
			history: none
			
			
			;-        lines:
			;
			; the actual content of the editor, is stored as a bulk of size 1
			; 
			; we will initialize this plug as a !text-lines plug which automatically
			; purifies input into the expected bulk when its not the case.
			lines: none
			
			
			;-        number-of-lines:
			; number of lines in lines material.
			number-of-lines: none
			
			
			;-        longest-line:
			;
			; length of longest line
			;
			; this value is filled-out rather lazily... we just keep incrementing it whenever a line is longer than this value.
			;
			; this can be linked to an horizontal scrollbar
			longest-line: none



			;-        view-size:
			; calculated editable area in pixels (dimension - padding - padding)
			view-size: none
			
			
			;-        view-width:
			; part of editor which actually can display characters in pixels (view-size/x)
			view-width: none
			
			
			;-        view-height:
			view-height: none
			
			
			;-        font-width:
			; extracts width from font.
			font-width: none
			
			
			;-        font-height:
			; extracts size from font.
			font-height: none
			
			
			;-        line-height:
			; font-height + leading
			line-height: none
			
			
			;-        visible-length:
			; number of characters that fit within view-width
			; this can be directly linked to scrollbar
			; view-width / font-width
			visible-length: none
			

			;-        visible-lines:
			; view-height / font/size
			visible-lines: none
			
			
			;-        hover-cursor:
			; whenever the mouse hovers over the interface, we update this value with the current
			; position of the mouse.
			;
			; its none when not focused or if the mouse is outside the view.
			hover-cursor: none
			
		
		]
		
		
		;-    valve[ ]
		valve: make valve [
			type: '!marble
		
			;-        style-name:
			style-name: 'script-editor  
			
			
			;-        editor-font:
			; font used by the gel, which is MONOSPACE for now and MUST include the char-width value within.
			editor-font: theme-editor-font
			
			
			;-        font-width:
			; used temporarily to calculate index 
			;font-width: theme-editor-char-width
			
			
			;-        cursor-x:
			cursor-x: 0
			highlight-x: 0
			
			hbox-s: 0x0
			hbox-e: 0x0
			
			clr1: none
			clr2: none
			clr3: none
			
			d: none ; dimension
			p: none ; position
			e: none ; box end (dimension + position)
			f?: none ; focused?
			c: none ; center
			
			highlight-color: 0.0.0.50
			

			;-        text-characters:
			text-characters: charset [#"a" - #"z"]


			
			;-----------------
			;-        materialize()
			;-----------------
			materialize: func [
				editor
				/local mtrl aspects
			][
				vin [{materialize()}]
				mtrl: editor/material
				aspects: editor/aspects
				
				mtrl/lines: liquify*/with/piped/fill !plug [ valve: make valve [pipe-server-class: epoxy-lib/!bulk-lines] ] ""
				
				attach*/preserve aspects/text mtrl/lines
				; we mutate the text aspect into a text bulk joiner.
				aspects/text/valve: epoxy-lib/!bulk-join-lines/valve
				
				mtrl/longest-line: liquify*/fill !plug 100
				
				mtrl/view-size: liquify*/link epoxy-lib/!pair-subtract [mtrl/dimension aspects/padding aspects/padding]
				mtrl/view-width: liquify*/link epoxy-lib/!x-from-pair mtrl/view-size
				mtrl/view-height: liquify*/link epoxy-lib/!y-from-pair mtrl/view-size
				
				
				mtrl/number-of-lines: liquify*/link glue-lib/!length mtrl/lines
				
				mtrl/font-width: liquify*/link/with glue-lib/!select aspects/font [attribute: 'char-width]
				mtrl/font-height: liquify*/link/with glue-lib/!select aspects/font [attribute: 'size]
				mtrl/line-height: liquify*/link glue-lib/!fast-add [mtrl/font-height aspects/leading]
				
				
				mtrl/visible-length: liquify*/link glue-lib/!divide [mtrl/view-width mtrl/font-width]
				mtrl/visible-lines: liquify*/link glue-lib/!divide [mtrl/view-height mtrl/line-height]
				
				mtrl/hover-cursor: liquify*/fill !plug none
				
				vout
			]
			
			
			
			;-----------------
			;-        get-lines()
			;-----------------
			get-lines: func [
				lines [block!]
				cursors [block! pair!]
				/local cursor line my-lines
			][
				vin [{get-lines()}]
				my-lines: copy []
				if pair? cursors [cursors: insert clear [] cursors]
				
				foreach cursor cursors [
					if line: pick next lines cursor/y [
						line: at line cursor/x
						append my-lines line
					]
				]
				vout
				
				
				my-lines
			]
			
			
			
			
			;-----------------
			;-        insert-char()
			;
			; this is currently very prototypish, but with more stuff implemented, it will get overhauled.
			;-----------------
			insert-char: func [
				key [char!] "the character to insert"
				cursors [block! pair!] ""
				lines [block!] "lines all setup, ready for insertion (any bulk header is skipped)"
				/local line k control? shift? cursor crs c
			][
				vin [{insert-char()}]
				
				if pair? cursors [cursors: insert clear [] cursors]
				
				until [
					cursor: first cursors
					
					if line: pick lines cursor/y [
						line: at line cursor/x
						insert line key
						cursor: cursor + 1x0
						crs: head cursors
						forall crs [
							c: first crs
							if all [
								c/y = cursor/y 
								c/x >= cursor/x
							][
								change crs (c + 1x0)
							]
						]

						change cursors cursor
					]
					tail? cursors: next cursors
				]
				
				vout
			]
			

			;-----------------
			;-        insert-text()
			;-----------------
			insert-text: func [
				text [string!] "the text to insert"
				cursors [block! pair!] "where to insert text"
				lines [block!] "lines all setup, ready for insertion (any bulk header is skipped)"
				/local line shift cursor str i line-i
			][
				vin [{insert-char()}]
				
				if pair? cursors [cursors: insert clear [] cursors]
				
				; get a compatible version of the text to our lines setup.
				text: text-to-lines text

				
				until [
					cursor: first cursors
					line: pick lines cursor/y
					text: head text
					
					;change cursors 1x0 + cursor
					
					case [
						(length? text ) >= 3 [
							; first line
							str: copy at line cursor/x
							clear at line cursor/x
							insert tail line first text
							
							i: (length? text) - 2
							shift: 1x1
							line-i: at lines cursor/y
							
							until [
								shift: shift + 0x1
								insert line-i: next line-i first text: next text
								0 = i: i - 1
							]
							
							; last lines
							insert next line-i  rejoin [ last text str ]
							str: second text
							shift: shift + (1x0 * ((length? str ) - cursor/x))
							move-cursors cursor head cursors ((0x1 * length? head text) - 0x1) shift shift
						]
						
						(length? text) = 2 [
							str: copy at line cursor/x
							clear at line cursor/x
							insert tail line first text
							insert next at lines cursor/y rejoin [ second text str ]
							str: second text
							shift: 1x0 * ((length? str ) - cursor/x) + 1x1
							move-cursors cursor head cursors 0x1 shift shift
						]
						
						(length? text) = 1 [
							insert at line cursor/x str: first text
							shift: (1x0 * length? str)
							move-cursors cursor head cursors 0x0 shift shift
						]
					
					]

					tail? cursors: next cursors
				]
				vout
			]

			;-----------------
			;-        delete-text()
			;
			; given two cursor positions, this will remove all text between them
			;-----------------
			delete-text: func [
				lines [block!] "lines all setup, ready for insertion (any bulk header is skipped)"
				from [pair!]
				to [pair!]
				/local top-down? shifts *to
			][
				vin [{delete-text()}]
				v?? from
				v?? to
				top-down?: true
				if any [
					from/y > to/y
					all [
						from/y = to/y 
						from/x > to/x
					]
				][
					swap-values from to
					top-down?: false
				]
				v?? top-down?
				*to: to
				until [
					; calculate box of current line to highlight
					either from/y = to/y [
						; first line
						line: pick lines to/y
						vprint "trimming first line"
						vprint line
						either to/x = -1 [
							clear at line from/x
							append line pick lines to/y + 1
							remove at lines to/y + 1
						][
							remove/part at line from/x at line to/x
						]
					][
						either to/x = -1 [
							;intermediate lines
							line: pick lines to/y
							remove at lines to/y
							vprint "removing line"
							vprint line
						][	
							; last line
							line: pick lines to/y
							remove/part line to/x - 1
							vprint "trimming last line"
							vprint line
						]
					]
					
					to: to - 0x1
					to/x: -1
					from/y > to/y
				]
				
				; calculate offsets.
				shifts: clear []
				v?? from
				v?? *to
				either top-down? [
					vprobe "TOP-DOWN"
					; inputs where swapped (cursor is at end of selection)
					append shifts *to - from * 0x-1
					append shifts *to - from * -1x-1 
					append shifts *to - from * -1x-1 ; - 1x0
					;curso
				][
					vprobe "DOWN-TOP"
					; input was left as-is (cursor is at head of selection)
					append shifts *to - from * 0x-1
					append shifts 0x0
					append shifts 0x0
				]
				
				vout
				shifts
			]
			
			
			;-----------------
			;-        delete-selections()
			;
			; given two cursor positions, this will remove all text between them
			;-----------------
			delete-selections: func [
				lines [block!] "lines all setup, ready for insertion (any bulk header is skipped)"
				cursors [block!]
				selections [block!]
				/local cursor selection deleted?  shifts
			][
				vin [{delete-text()}]
				; selections will always be cleared by normal mouse swiping
				; so we can safely use this as a quick check.
				;
				; this prevents us from having to scan the cursors/selections at each
				; key stroke... much faster.
				unless empty? selections [
					repeat i length? cursors [
						if all [
							cursor: pick cursors i
							selection: pick selections i
							cursor <> selection ; we ignore cursors without selection
						][
							shifts: delete-text lines selection cursor
							deleted?: true
							move-cursors cursor cursors shifts/1 shifts/2 shifts/3
						]
					]
					clear selections
				]
				vout
				deleted?
			]
			
			
			;-----------------
			;-        clean-selections()
			;
			; this function cleans the selections if none of the pairs actually constitute
			; a range when compared to cursors.
			;
			;-----------------
			clean-selections: func [
				"Will clean the selection based on cursors, if selections are useless"
				cursors [block!]
				selections [block!]
				/local cursor selection
			][
				vin [{clean-selections()}]
				v?? cursors
				v?? selections
				unless empty? selections [
					cursors: at cursors length? selections
					selections: back tail selections
					until [
						if all [
							cursor: pick cursors 1
							selection: pick selections 1
						][
							either selection <> cursor [
								; at this point, we have a selection, the previous ones will now be valid.
								break
							][
								; they are the same, so no selection should occur
								remove selections
							]
						]
						cursors: back cursors
						selections: back selections
						empty? head selections
					]
				]
				vout
			]
			
			;-----------------
			;-        fill-selections()
			;
			; does the opposite of clean-selections by filling up the selections with
			; missing cursors.
			;-----------------
			fill-selections: func [
				cursors [block!]
				selections [block!]
			][
				vin [{fill-selections()}]
				vout
				if shorter? selections cursors [
					elongate selections cursors
				]
			]
			
			
			;-----------------
			;-        select-word()
			;-----------------
			select-word: func [
				lines [block!] "lines all setup, ready for insertion (any bulk header is skipped)"
				cursors [block!]
				selections [block!]
				cursor [pair!]
				/local line char selection
			][
				vin [{select-word()}]
				if all[
					line: pick lines cursor/y 
					char: pick line cursor/x 
				][
					either find **whitespace char [
						; select spacing
						;until [
						;]
					][
						; select word
						line: at line cursor/x
						
						; find head of word 
						until [
							line: back line
							any [
								all[
									find **whitespace pick line 1 
									line: next line
								]
								head? line
							]
						]
						selection: 1x0 * (index? line) + (0x1 * cursor)
						; find tail of word 
						line: at head line cursor/x
						until [
							line: next line
							any [
								tail? line
								find **whitespace pick line 1
							]
						]
						cursor: 1x0 * (index? line) + (0x1 * cursor)
						
						elongate cursors selections
						
						change back tail selections selection
						change back tail cursors cursor
					]
				]
				
				vout
			]
			
			
			
			
			;-----------------
			;-        select-line()
			;-----------------
			select-line: func [
				lines [block!] "lines all setup, ready for insertion (any bulk header is skipped)"
				cursors [block!]
				selections [block!]
				cursor [pair!]
				/local line char selection
			][
				vin [{select-line()}]
				if line: pick lines cursor/y [
					elongate cursors selections
					
					change back tail selections (0x1 * cursor) + 1x0
					change back tail cursors 1x0 * (length? line) + (0x1 * cursor) + 1x0
				]
			
				vout
			]
			
			
			
			
			
			;-----------------
			;-        get-selection()
			;-----------------
			get-selection: func [
				lines [block!] "lines all setup, ready for insertion (any bulk header is skipped)"
				cursors [block!]
				selections [block!]
				/with-newlines
				/local selection cursor line text
			][
				vin [{get-selection()}]
				text: clear ""
				
				until [
					if selection: pick selections 1 [
						if all [
							cursor: pick cursors index? selections
							cursor <> selection 
						][
							; normalize direction of cursor/selection
							if any [
								cursor/y < selection/y
								all [cursor/y = selection/y cursor/x < selection/x]
							][
								swap-values cursor selection
							]
							
							until [	
								if line: pick lines selection/y [
									either cursor/y = selection/y [
										; last line or single line
										append text copy/part at line selection/x at line cursor/x
									][
										; other lines
										append text copy/part at line selection/x tail line
										append text newline
									]
								]
								selection: selection + 0x1
								selection/x: 1
								selection/y > cursor/y
							]
						]
						if with-newlines [
							append text newline
						]
					]
					tail? selections: next selections
				]
				if all [
					not empty? text 
					with-newlines 
				][
					remove back tail text
				]
				vout
				copy text
			]
			
			
			
			

			
			;-----------------
			;-        font-box()
			;-----------------
			font-box: func [
				marble [object!]
				/local box font
			][
				vin [{font-box()}]
				font: content* marble/aspects/font
				box: (font/size + (content* marble/aspects/leading) * 0x1) + (font/char-width * 1x0)
				vout
				box
			]
			
			
			
			;-----------------
			;-        move-cursors()
			;-----------------
			move-cursors: func [
				"pushes all cursors following cursor movement"
				cursor [pair!]
				cursors [block!]
				below-amount [pair!]
				same-line-amount [pair!]
				same-amount [pair!]
				/local c s
			][
				vin [{move-cursors()}]
				
				
				; update other cursors
				until [
					vprint "---"
					c: first cursors
					v?? cursor
					v?? c
					v?? cursors
					vprint head cursors
					case [
						; lines below cursor
						c/y > cursor/y [
							vprint ["below: " below-amount ] 
							change cursors c + below-amount
							if s: pick selections 1 [
								change selections s + below-amount
							]
						]
						
						; same cursor
						c = cursor [
							vprint ["same cursor: " same-amount ] 
							change cursors c + same-amount
							if s: pick selections 1 [
								change selections s + same-amount
							]
						]
						
						; same line as cursor, but later on the line
						all [
							c/x > cursor/x
							c/y = cursor/y
						][
							vprint ["same line: " same-line-amount ] 
							change cursors c + same-line-amount
							if s: pick selections 1 [
								change selections s + same-line-amount
							]
						]
						
						true [0x0]
					]
					selections: next selections
					tail? cursors: next cursors
				]
				cursors: head cursors
				
				vout
			]
			
			
			
			
			;-----------------
			;-        handle-key()
			;
			; this is meant to handle any key based editing of the editor.
			;
			; at this point, we know its not a control key or a shortcut key the application.
			; invalid keys simply do nothing.
			;-----------------
			handle-key: func [
				marble [object!]
				event [object!]
				/local dirty? lines cursors cursor offset new crs c line amount keep-stored-cursors? text
			][ 
				vin [{handle-key()}]
				
				lines: next content* marble/material/lines
				cursors: content* marble/aspects/cursors
				selections: content* marble/aspects/selections


				vprobe event/key

				switch/default event/key [
					;----------------
					;-            -enter
					;----------------
					enter [
						delete-selections lines cursors selections
						until [
							cursor: first cursors
							if line: pick lines cursor/y[
								line: at line cursor/x
								new: copy line
								clear line
								insert at lines (cursor/y + 1) new
								
								move-cursors cursor head cursors  0x1  amount: (0x1 + (-1x0 * length? head line) ) amount 
								
								dirty?: true
							]
							tail? cursors: next cursors
						]
						remove-duplicates head cursors
					]
					
					;----------------
					;-            -erase-current
					;
					; delete key (on windows)
					;----------------
					erase-current [
						v?? cursors 
						v?? selections
						either delete-selections lines cursors selections [
							dirty?: true
						][
							until [
								cursor: first cursors
								if line: pick lines cursor/y [
									line: at line cursor/x
									
									; are we at the end of the line?
									either empty? line [
										; join this line with next one
										if new: pick lines cursor/y + 1 [
											v?? new
											append line new
											remove at lines cursor/y + 1
											move-cursors cursor head cursors  0x-1 0x0 0x0
										]
									][
										; delete one char from the line.
										remove line
										move-cursors cursor head cursors  0x0 -1x0 0x0 
	
									]
									dirty?: true
								]
								tail? cursors: next cursors
							]
						]
						remove-duplicates head cursors	
					]

					;----------------
					;-            -erase-previous
					;
					; backspace key (on windows)
					;----------------
					erase-previous [
						either delete-selections lines cursors selections [
							dirty?: true
						][
							until [
								cursor: first cursors
								if cursor = 1x1 [break]
								if line: pick lines cursor/y [
									line: at line cursor/x
									
									; are we at the begining of the line?
									either cursor/x = 1 [
										; join this line with previous one
										if all [
											cursor/y > 1
											new: pick lines cursor/y - 1 
										][
											v?? new
											
											amount: ( 1x0 * length? new) + 0x-1
											
											v?? amount
											
											append new line
											remove at lines cursor/y
											move-cursors cursor head cursors  0x-1 amount amount
										]
									][
										; delete one char from the line.
										remove back line
										move-cursors cursor head cursors  0x0 -1x0 -1x0 
	
									]
									unless dirty? [dirty?: true]
								]
								tail? cursors: next cursors
							]
							remove-duplicates head cursors	
						]
					]
					
					;----------------
					;-            -escape
					;----------------
					escape [
						; this will unfocus one cursor at a time, until there is only one cursor
						;
						; removes newer cursors by default,
						; pressing shift removes older cursors
						;
						; we cannot map ctrl + escape since this is used natively by Windows!
						if 1 < length? cursors [
							either event/shift? [
								remove cursors
							][
								clear back tail cursors
								if shorter? cursors selections [
									shorten selections cursors
								]
							]
							dirty?: true
						]
					]
					
					
					;----------------
					;-            -move-up / move-down
					;
					; up down arrow keys
					;----------------
					move-up move-down [
						either event/shift? [
							fill-selections cursors selections
						][
							clear selections
						]
						offset: either event/key = 'move-up [0x-1][0x1]
							
						until  [
							cursor: first cursors
							either marble/stored-cursors [
								cursor/x: first pick marble/stored-cursors index? cursors
							][
								marble/stored-cursors: copy cursors
							]
							unless any [
								all [
									event/key = 'move-up
									cursor/y < 2
								]
								all [
									event/key = 'move-down
									cursor/y >= length? lines
								]
							] [
								cursor: add offset cursor
								cursor/x: min cursor/x 1 + length? pick lines cursor/y
								change cursors cursor
								
								unless dirty? [dirty?: true]
							]
							tail? cursors: next cursors
						]
						keep-stored-cursors?: true
					]
					
					
					;----------------
					;-            -move-left
					;
					; left arrow key
					;----------------
					move-left [
						either event/shift? [
							fill-selections cursors selections
						][
							clear selections
						]
						until  [
							cursor: first cursors
							line: pick lines cursor/y
							
							either any [
								cursor/x <= 1
								empty? line
							][
								unless cursor/y <= 1 [
									; we need to wrap to previous line
									cursor/y: cursor/y - 1
									line: pick lines cursor/y
									change cursors (cursor  + (1x0 * length? line))
									unless dirty? [dirty?: true]
								]
							][
								change cursors -1x0 + cursor
								unless dirty? [dirty?: true]
							]
							tail? cursors: next cursors
						]
					]


					;----------------
					;-            -move-right
					;
					; right arrow key
					;----------------
					move-right [
						either event/shift? [
							fill-selections cursors selections
						][
							clear selections
						]
						until [
							cursor: first cursors
							line: pick lines cursor/y
							
							either cursor/x > length? line [
								unless cursor/y >= length? lines [
									; we need to wrap to previous line
									cursor/y: cursor/y + 1
									line: pick lines cursor/y
									change cursors (cursor * 0x1 + 1x0)
									unless dirty? [dirty?: true]
								]
							][
								change cursors 1x0 + cursor
								unless dirty? [dirty?: true]
							]
							tail? cursors: next cursors
						]
					]
					
					

					;----------------
					;-            -move-to-begining-of-line
					;
					; home key
					;----------------
					move-to-begining-of-line [
						either event/shift? [
							fill-selections cursors selections
						][
							clear selections
						]
						until [
							cursor: first cursors
							line: pick lines cursor/y
							
							change cursors (cursor * 0x1) + 1x0
							
							tail? cursors: next cursors
						]
						dirty?: true
					]
					
					
					
					;----------------
					;-            -move-to-end-of-line
					;
					; end key
					;----------------
					move-to-end-of-line [
						either event/shift? [
							fill-selections cursors selections
						][
							clear selections
						]
						until [
							cursor: first cursors
							line: pick lines cursor/y
							
							change cursors (cursor * 0x1) + (1x0 * length? line) + 1x0
							
							tail? cursors: next cursors
						]
						dirty?: true
					]
					
					
					
					;----------------
					;-            -paste
					;
					; (Ctrl+V on windows)
					;----------------
					paste [
						delete-selections lines cursors selections
						if text: read clipboard:// [
							insert-text text cursors lines
							unless dirty? [dirty?: true]
						]
					]
					
					;----------------
					;-            -copy
					;
					; (Ctrl+C on windows)
					;----------------
					copy [
						unless empty? selections [
							either event/shift? [
								write clipboard:// get-selection/with-newlines lines cursors selections
							][
								write clipboard:// get-selection lines cursors selections
							]
							dirty?: true
						]
					]
					
					;----------------
					;-            -cut
					;
					; (Ctrl+X on windows)
					;----------------
					cut [
						unless empty? selections [
							either event/shift? [
								write clipboard:// get-selection/with-newlines lines cursors selections
							][
								write clipboard:// get-selection lines cursors selections
							]
							delete-selections lines cursors selections
							dirty?: true
						]
					]
				][
					;----------------
					;-            -type a character
					;----------------
					if all [
						char? event/key
						not event/control?
					][
						delete-selections lines cursors selections
						insert-char event/key cursors lines
						update-longest-line marble lines
						dirty?: true
					]
				]
				
				if dirty? [
					dirty* marble/material/lines
					dirty* marble/aspects/cursors
				]
				
				unless keep-stored-cursors? [
					marble/stored-cursors: none
				]
					
				
				vout
			]
			
			
			;-----------------
			;-        update-longest-line()
			;-----------------
			update-longest-line: func [
				"Using current cursors and optional lines, adjust longest-line, so it shows all content"
				marble [object!]
				lines [block!]
				/local item line in-len
			][
				vin [{update-longest-line()}]
				
				in-len: len: content* marble/material/longest-line
				
				; update based on cursors
				foreach line lines [
					len: max len (10 + length? line)
				]
				if in-len <> len [
					fill* marble/material/longest-line len
				]
				
				vout
				len
			]
			
			
			
			;-----------------
			;-        cursor-from-offset()
			;-----------------
			cursor-from-offset: func [
				marble [object!]
				offset [pair!]
				/local box lines line cursor
			][
				vin [{cursor-from-offset()}]
				padding: content* marble/aspects/padding
				box: font-box marble
				
				; we select the character based on if we click to the left or right of a character
				; this way, if we click nearer to the next char, it is selected instead of the one
				; we are actually over.
				;
				; this is because we actually select the region "between" chars as opposed to chars themselves.
				offset/x: offset/x + (box/x / 2 )
				
				cursor: (offset - padding / box + 1x0 ) + (0x1 * content* marble/aspects/top-off) + (1x0 * content* marble/aspects/left-off ) - 1x0
				lines: next content* marble/material/lines
				
				
				if cursor/y < 1 [
					cursor/y: 1
				]
				
				if cursor/y > length? lines [
					cursor/y: length? lines
				]
				
				line: pick lines cursor/y
				cursor/x: min cursor/x (1 + length? line )

				vout
				cursor
			]
						
			

			;-----------------
			;-   ** editor-handler() **
			;
			; this handler is used for testing purposes only. it is shared amongst all marbles, so its 
			; a good and memory efficient handler.
			;-----------------
			editor-handler: func [
				event [object!]
				/local editor i mtrl aspects cursor cursors
			][
				vin [{HANDLE EDITOR}]
				vprint event/action
				
				editor: event/marble
				mtrl: editor/material
				aspects: editor/aspects
				
				switch/default event/action [
					start-hover [
						fill* aspects/hover? true
					]
					
					end-hover [
						fill* aspects/hover? false
					]
					
					hover [
						fill* mtrl/hover-cursor cursor-from-offset editor event/offset
						false
					]
					
					;-             -select
					select [
						vprint event/coordinates
						vprint ["tick: " event/tick]
						vprint ["fast-clicks: "event/fast-clicks]
						vprint ["coordinates: " event/coordinates]
						unless content* event/marble/aspects/focused? [
							; tell the system that WE want to be focused
							event/action: 'focus
							event-lib/queue-event event
						]
						
						cursor: cursor-from-offset editor event/offset
						cursors: content* editor/aspects/cursors
						selections: content* editor/aspects/selections
						lines: next content* editor/material/lines
						
						
						
						
						
						either event/fast-clicks [
							;probe event/fast-clicks
							switch event/fast-clicks [
								1 [
									select-word lines cursors selections cursor
								]
								
								2 [
									select-line lines cursors selections cursor
								]
								
								3 [
									;select-paragraph lines cursor
								]
							]
						][

							either event/control? [
								append cursors cursor
							][
								append clear cursors cursor
								clear selections
								dirty* editor/aspects/selections
							]
						]
						dirty* editor/aspects/cursors
						
						; we store the cursors, so swipe can detect if a new selection is occuring while dragging the mouse.
						editor/stored-cursors: copy cursors
						
					]
					
					;-             -scrollwheel
					scroll focused-scroll [
						switch event/direction [
							push [
								fill* aspects/top-off max 1 ((content* aspects/top-off) - event/amount)
							]
							pull [
								fill* aspects/top-off max 1 ((content* aspects/top-off) + event/amount)
							]
						]
					]
					
										
					;-             -swipe
					swipe drop? [
						;set-cursor-from-coordinates event/marble event/offset true
						vprint 'swiping
						cursor: cursor-from-offset editor event/offset
						cursors: content* editor/aspects/cursors
						selections: content* editor/aspects/selections
						
						; first make sure we have as many selections as cursors
						if fill-selections cursors selections [dirty* editor/aspects/selections]
						
						
						; remove selections if they don't constitute an actual selection.
						; this is to make sure that we can do:
						;
						;  if empty? selections []
						;
						; in order to trigger selection code without it slowing down non selection
						; code within keystrokes.
						;
						; because the swipping does little else, it will not slow this down.
						if cursor <> last editor/stored-cursors  [
							change back tail selections last editor/stored-cursors
						]
						change back tail cursors cursor-from-offset editor event/offset
						clean-selections cursors selections
						
						v?? selections
						v?? cursors
						
						dirty* editor/aspects/cursors
						fill* editor/material/hover-cursor cursor
					]
					
					focus [
						if pair? event/coordinates [
						;	set-cursor-from-coordinates event/marble event/offset false
						]
						fill* aspects/focused? true
					]
					
					
					unfocus [
						fill* aspects/focused? false
					]
					
					
					;-             -text-entry
					text-entry marble-text-entry [
						handle-key editor event
					]
				][
					vprint "IGNORED"
				]
				
				
				
				vout
				none
			]
			
			;-----------------
			;-        setup-style()
			;-----------------
			; a callback to extend anything in the marble AFTER Glass has finished with its own setup
			;
			; this is used by styles for their own custom data requirements.
			;
			; styles may also provide application setup hooks, but usually do so via extensions to the
			; the specification parser, using dialect()
			; 
			; some styles will also add default stream handlers (like viewports)
			;-----------------
			setup-style: func [
				marble
			][
				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/stylize()}]
				
				; just a quick stream handler for all marbles
				event-lib/handle-stream/within 'editor-handler :editor-handler marble
				vout
			]
			
			
			

		
			;-----------------
			;-        dialect()
			;
			; this uses the exact same interface as specify but is meant for custom marbles to 
			; change the default dialect.
			;
			; note that the default dialect is still executed, so you may want to "undo" what
			; it has done previously.
			;
			;-----------------
			dialect: func [
				marble [object!]
				spec [block!]
				stylesheet [block!] "Required so stylesheet propagates in marbles we create"
				/local data img-count icon
			][
				vin [{dialect()}]
				img-count: 1
				
				;print "!"
				
				parse spec [
					any [
						set data string! (
							fill* marble/aspects/text data
						)
						| skip
					]
				]

				vout
			]			


			
			;-        glob-class:
			; defines the glob which will be built by each marble instance.
			;   glob-class/marble  is added automatically by setup.
			glob-class: make !glob [
				valve: make valve [
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup these will be stored within glob/input
						position !pair (random 200x200)
						dimension !pair (100x30)
						color !color  (random white)
						text !string ("")
						focused? !bool
						hover? !bool
						left-off !integer
						top-off !integer
						lines !block
						leading !integer
						cursors !block
						view-size !pair
						padding !pair
						selections !block
					]
					
					;-            glob/gel-spec:
					; different AGG draw blocks to use, one per layer.
					; these are bound and composed relative to the input being sent to glob at process-time.
					gel-spec: [
						; event backplane
						position dimension 
						[
							line-width 1 
							pen none 
							fill-pen (to-color gel/glob/marble/sid) 
							box (data/position=) (data/position= + data/dimension= - 1x1)
						]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						position dimension color lines hover? focused? left-off top-off leading cursors view-size padding selections
						[
							(
								;print "!!!"
								d: data/dimension=
								p: data/position=
								e: d + p - 1x1
								c: d / 2 + p - 1x1
								f?: data/focused?=
								;vrange: visible-range gel/glob/marble 
								;cursor-x: ( data/cursor-index= - data/left-off= + 1 * font-width) * 1x0
;								if data/cursor-highlight= [
;									highlight-x: ( data/cursor-highlight= + 1 - data/left-off= * font-width) * 1x0
;									hbox-s: min (max p + 0x1 (cursor-x + p + -3x0)) e + 0x-1
;									hbox-e: min (max p + 0x3 (p + highlight-x + (0x1 * d) - 3x1)) e - 0x1
;								]
							 []
							)
							line-width 1
							pen none
							
							; bg
							fill-pen linear (p) 1 (d/y) 90 1 1 
;								(either f?  [wheat * .95 + 20.20.20][white * .98]) 
;								(either f?  [wheat * .95 + 20.20.20][white * .98]) 
;								(either f? [wheat + 20.20.20][white]) 
								(white * .98) 
								(white * .98) 
								(white) 
							box (p) (e) 3
							
;							(
;								either data/focused?= [
;									compose [
;										fill-pen (theme-color + 0.0.0.240)
;										box (p) (e) 3
;									]
;								][[]]
;							)
							

							; top shadow
							fill-pen linear (p + 0x1) 1 (4) 90 1 1 
								(0.0.0.150) 
								(0.0.0.220) 
								(0.0.0.240) 
								(0.0.0.255 )
							box (p) (e) 3

							
							
							pen none
;							(
;								either all [data/cursor-highlight= data/focused?=] [
;									compose [
;										fill-pen 255.255.255.200
;										box (hbox-s) (hbox-e) 3
;									]
;								][[]]
;							)
							
							
							
							fill-pen none
							
							; basic text
							line-width 1
							pen (data/color=)
							(
								either f?  [ 
								 ;probe data/lines=
								 ;- PRIM TEXT CALL
									prim-text-area/cursor-lines (p + data/padding=) data/view-size= data/lines= theme-editor-font data/leading= data/left-off= data/top-off= data/cursors= data/selections= red black  (theme-color + 0.0.0.200) yellow
								][
									prim-text-area (p + data/padding=) data/view-size= data/lines= theme-editor-font data/leading= data/left-off= data/top-off= data/cursors= data/selections= black black theme-color + 0.0.0.200
								]
							)
							
														
							(	
								either f?  [ 
									compose [
										
										
											; highlight box
;										(
;										 	compose either data/cursor-highlight= [
;										 		prim-glass hbox-s hbox-e theme-color 190
;										 		
;												[
;													line-width 1
;													
;													
;													fill-pen linear (p) 1 (d/y) 90 1 1 ( highlight-color * 0.6 + 128.128.128.150) ( highlight-color + 0.0.0.150) (highlight-color * 0.5 + 0.0.0.150)
;													pen (black + 0.0.0.150)
;													box  ( hbox-s ) (hbox-e )
;													
;													
;													; shine
;													pen none
;													fill-pen (255.255.255.175)
;													box ( top-half  ( hbox-s + 0x2) (hbox-e - hbox-s ) )
;													
;													; shadow
;													fill-pen linear (p + 0x15) 1 10 90 1 1 
;														0.0.0.255
;														0.0.0.200
;														0.0.0.150
;													box ( hbox-s + 0x15) (hbox-e )
;												]
;											][
;												[]
;											]
;										)
										
										; add cursor
;										(
;										 	compose either data/cursor-highlight= [
;										 		[
;													pen (red)
;													fill-pen none
;													line-width 1
;													line ( cursor-x + p - 2x0)
;													     (p + cursor-x + (0x1 * d) - 2x2)
;												]
;											][
;												[
;													pen (red)
;													fill-pen none
;													line-width 2
;													line ( cursor-x + data/position= - 3x0)
;													     (data/position= + cursor-x + (0x1 * data/dimension=) - 3x2)
;												]
;											]
;										)
									]
								][
									[]
								]
							)


							


							; draw edge highlight?
							( 
								;print "--------->" 
								compose either any [data/hover?= f? ][
									[
										line-width 2
										fill-pen none
										pen (theme-color + 0.0.0.175)
										box (data/position= + 1x1) (data/position= + data/dimension= - 2x2) 3
										pen white
										fill-pen none
										line-width 1
										box (data/position=) (data/position= + data/dimension= - 1x1) 3
									]
								][[
									; simple gray border
									pen theme-border-color
									fill-pen none
									line-width 1
									box (data/position=) (data/position= + data/dimension= - 1x1) 3
								]]
							)
							
							;clip 0x0 10000x10000

						]
							
						; controls layer
						;[]
						
						; overlay layer
						; like the bg, it may switched off, so don't depend on it.
						;[]
					]
				]
			]
			

			
			
		]
	]
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %style-editor.r 
    date: 20-Jun-2010 
    version: 0.8.0 
    slim-name: 'style-script-editor 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: STYLE-SCRIPT-EDITOR
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: GLUE  v0.1.0
;--------------------------------------------------------------------------------

append slim/linked-libs 'glue
append/only slim/linked-libs [


;--------
;-   MODULE CODE




;- slim/register/header
slim/register/header [
	; declare words so they stay bound locally to this module
	!plug: liquify*: !glob: content*: fill*: link*: unlink*: process*: none
	
	liquid-lib: slim/open/expose 'liquid none [!plug [liquify* liquify ] [content* content] [fill* fill] [link* link] [process* process]]

	
	;------------------------------
	;-     !select[p]
	;
	;  given data, return a component of that data.  each type handles itself differently.
	;
	;  inputs:
	;
	;    dataset: [block! object!]  data to select from
	;
	;  
	;  optional inputs:
	;     
	;    attribute: [any! word!] if dataset is a block, we can select anything,
	;                            if dataset is an object, we can only select words
	;
	;  output:
	;    the value of dataset/attribute
	;
	;  notes:
	;    because of the inherintly low-level nature of this plug, we do not do any error checking
	;    beyond receiving all inputs.
	;
	;    we may return none if any problem occurs.
	;
	;  when attribute is not given, we use the "attribute" field within the 
	;
	;------------------------------
	!select: process*/with '!select [dataset attr ][
		plug/liquid: if all [
			dataset: pick data 1
			attr: any [pick data 2 plug/attribute]
		][
			switch type?/word dataset [
				object! [
					get in dataset attr
				]
				
				block! [
					select dataset attr
				]
			]
		]
	][
		attribute: none
	
	]
	
	;------------------------------
	;-     !length[p]
	;
	;  given data, returns its length
	;
	;  inputs:
	;
	;    dataset: [block! object!]  any length?-able value.
	;    
	;  output:
	;    length of input
	;
	;  notes:
	;    because of the inherintly low-level nature of this plug, we do not do any error checking
	;    beyond recieving input.
	;
	;------------------------------
	!length: process* '!select [][
		plug/liquid: either all [
			data: pick data 1
		][
			length? data
		][
			0
		]
	]
	
	
	;------------------------------
	;-     !op[p]
	;
	;  given data, applies a function to each value, storing each result as the operand for the next pass.
	;
	;  inputs:
	;
	;    series of scalar values. (should usually always be of the same type)
	;    
	;  output:
	;    length of input
	;
	;  notes:
	;    because of the inherintly low-level nature of this plug, we do not do any error checking
	;    beyond receiving input.
	;
	;    supplying incompatible data inputs WILL CAUSE AN ERROR!
	;
	;------------------------------
	!op: process*/with 'op [item][
		plug/liquid: pick data 1 0
		operation: get in plug 'operation
		foreach item next data [
			plug/liquid: operation plug/liquid item
		]
	][
		; set this to any function you need within your class derivative.
		;
		; note that operation is bound when the class is created, so you cannot
		; change it live, it will not react.
		operation: :add
	]


	;------------------------------
	;-     !divide[p]
	;
	;  a preset !op type
	;
	; just saves a bit of ram if it doesn't need to be re-defined at each instance.
	;
	;------------------------------
	!divide: make !op compose [operation: :divide valve: make valve[]]



	
	;-     !fast-add:
	; fast add function.
	!fast-add: process*  '!fast-add [] [
		plug/liquid: if 1 < length? data [
			add first data second data
		][0]
	]
		
	;------------------------------
	;-     !gate[p]
	;
	;  returns a value only if some condition is met, returns none or a linked default otherwise. 
	;
	;  inputs:
	;
	;    this plug has different functionality, based on how many links it has!
	;
	;    	2) value: the value to pass    
	;          gate-switch: when condition matches the gate-switch value is passed
	;
	;    	3) value: the value to pass    
	;          trigger: when trigger satisfies mode, the value is passed.
	;          default:  this value is returned while trigger is invalid
	;
	;  output:
	;    the input value, none, or an optional default value.
	;
	;  notes:
	;    the plug has a mode which changes how the trigger is interpreted.
	;
	;------------------------------
	!gate: process*/with 'gate [value trigger default][
		value: pick data 1
		trigger: pick data 2
		default: any [pick data 3 plug/default-value] ; if nothing specified, this ends up being none.
		
		plug/liquid: switch to-lit-word plug/mode [
			'if [
				either trigger [value][default]
			]
			'true [
				either trigger = true [value][default]
			]
			'not [
				either not trigger [value][default]
			]
			'none [
				either trigger = none [value][default]
			]
			'equal [
				either trigger = value [value][default]
			]
			'different [
				either trigger <> value [value][default]
			]
		]
	][	
		;-         mode:
		mode: 'if ; if ,true, not, none, equal, different
		
		;-         default-value:
		; you can provide a static default, when creating links is not practical
		default-value: none
		
	]
	
	
	
	;------------------------------
	;-     !latch[p]
	;
	; this is a very special Plug which tampers with usual messaging on purpose
	;
	; it basically acts like a double coil latching relay.
	; 
	; you can use it directly to detect when some input plugs have changed since a manual resett.
	;
	; mode
	; ----
	;   it must ALWAYS be used in linked-container mode
	;
	; inputs
	; ----
	;    1: the change trigger [any!] whenever this link changes, the output switches to triggered until reset by a fill.
	;
	; optional inputs:
	; ----
	;    it may have one or two optional inputs 
	;    	2: value when data is triggered
	;
	;       3: value when node is reset
	;
	; functioning:
	; ----
	;    as opposed to other nodes, this one doesn't propagate to children when inputs change each time.
	;    it only propagates when the plug goes from one state to another (triggered, reset)
	;
	;    Any dirty call which is sent from the first link will switch plug to triggered state.
	;
	;    To reset the node, simply fill-it with a value which is different than the last time you filled it.
	;    a random number is a good trigger value.
	;
	; note:
	; ---- 
	;    doesn't support stainless? mode
	;
	;    this node allows liquid to actually break cycles in propagation, since only the first dirty will ever traverse. it doesn't
	;    cure instigation cycles though.
	;
	;    this is one of the nodes which really illustrate how flexible and powerfull liquid's api architecture really is.
	;    since it changes the messaging model while still being 100% compatible to other plugs.
	;
	;------------------------------
	!latch: make !plug [
	
		resolve-links?: true
	
		;-         previous-reset:
		previous-reset: none
		
		
		;-         changed?:
		changed?: none
		
		;-         valve[]
		valve: make valve [
			type: 'latch
	
			;---------------------
			;-             dirty()
			;---------------------
			; react to our link and fill being set to dirty.
			;
			;---------------------
			dirty: func [
				plug "plug to set dirty" [object!]
				/always "do not follow stainless? as dirty is being called within a processing operation.  prevent double process, deadlocks"
				/local link-dirty?
			][
				vin ["liquid/" plug/valve/type "[" plug/sid "]/dirty()"]
				
				; this node doesn't support being stainless.
				
				link-dirty?: if sub: pick plug/subordinates 1  [
					get in sub 'dirty?
				]
				
				; dirty caused by fill
				either plug/previous-reset <> plug/mud [
					plug/changed?: false
					plug/previous-reset: plug/mud
					propagate/dirty plug
				][
					;dirty caused by link update
					if all[
						link-dirty?
						not plug/changed?
					][
						plug/changed?: true
						propagate/dirty plug
					]
				]
				
				; clean up
				plug: none
				vout
			]
			
			
			process: func [plug data][
			
				vin "glue/latch/process()"
				
				plug/liquid: case [	
					4 = length? data [pick next next data plug/changed?]
					3 = length? data [if plug/changed? [third data]]
					true [plug/changed?]
				]
				vout
			]
		]
	]	
		
	
]

;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %glue.r 
    date: 20-Jan-2011 
    version: 0.1.0 
    slim-name: 'glue 
    slim-prefix: none 
    slim-version: 0.9.14 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: GLUE
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: STYLE-BUTTON  v0.5.3
;--------------------------------------------------------------------------------

append slim/linked-libs 'style-button
append/only slim/linked-libs [


;--------
;-   MODULE CODE



;- slim/register/header
slim/register/header [
	; declare words so they stay bound locally to this module

	layout*: get in system/words 'layout
	
	

	;- LIBS
	to-color: none
	
	!glob: none
	glob-lib: slim/open/expose 'glob none [!glob to-color]
	
	marble-lib: slim/open 'marble none
	event-lib: slim/open 'event none
	
	!plug: liquify*: content*: fill*: link*: unlink*: none
	liquid-lib: slim/open/expose 'liquid none [
		!plug 
		[liquify* liquify ] 
		[content* content] 
		[fill* fill] 
		[link* link] 
		[unlink* unlink] 
		[dirty* dirty]
	]
	
	
	prim-bevel: prim-x: prim-label: prim-knob: none
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: none
	top-half: bottom-half: none
	sillica-lib: slim/open/expose 'sillica none [
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		prim-bevel
		prim-x
		prim-label
		prim-knob
		top-half
		bottom-half
	]
	epoxy-lib: slim/open/expose 'epoxy none [!box-intersection]

	

	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;

	;--------------------------------------------------------
	;-   
	;- !BUTTON[ ]
	!button: make marble-lib/!marble [
	
		;-    Aspects[ ]
		aspects: make aspects [
			
			;-        focused?:
			; some buttons can be highlighted (ex: ok/cancel in requestors)
			focused?: false
			
			;-        pressed?:
			selected?: false
			
		
			;-        label:
			label: "button"
			
			
			;-        color:
			color: theme-knob-color


			;-        label-color:
			label-color: black
			
			font: theme-knob-font
			
		]

		
		;-    Material[]
		material: make material []
		
		
		
		
		
		
		
		;-    valve[ ]
		valve: make valve [
		
			type: '!marble
		
			;-        style-name:
			; used as a label for debugging and node browsing.
			style-name: 'button  
			
			
			;-        label-font:
			; font used by the gel.
			;label-font: theme-knob-font
			
			;-        glob-class:
			; defines the glob which will be built by each marble instance.
			;   glob-class/marble  is added automatically by setup.
			glob-class: make !glob [
				pos: none
				
				valve: make valve [
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup these will be stored within glob/input
						position !pair (random 200x200)
						dimension !pair (100x30)
						color !color  (random white)
						label-color !color  (random white)
						label !string ("")
						focused? !bool
						hover? !bool
						selected? !bool
						align !word
						padding !pair
						font !any
					]
					
					;-            glob/gel-spec:
					; different AGG draw blocks to use, one per layer.
					; these are bound and composed relative to the input being sent to glob at process-time.
					gel-spec: [
						; event backplane
						position dimension 
						[
							line-width 1 
							pen none 
							fill-pen (to-color gel/glob/marble/sid) 
							box (data/position=) (data/position= + data/dimension= - 1x1)
						]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						position dimension color label-color label align hover? focused? selected? padding font
						[
							(
								;print [ data/label= ": " data/label-color= data/color=]
								;draw bg and highlight border?
								any [
									all [ data/hover?= data/selected?= compose [
											; bg color
											pen none
											line-width 0
											fill-pen linear (data/position=) 1 (data/dimension=/y) 90 1 1 ( data/color= * 0.6 + 128.128.128) ( data/color= ) (data/color= * 0.7 )
											box (data/position= + 1x1) (data/position= + data/dimension= - 1x1) 2
	
											; shine
											pen none
											fill-pen (data/color= * 0.7 + 140.140.140.128)
											box ( top-half  data/position= data/dimension= ) 2
											
											;inner shadow
											pen shadow ; 0.0.0.50
											line-width 2
											fill-pen none
											box (data/position= + 1x1) (data/position= + data/dimension= - 2x2) 2
	
											pen none
											line-width 0
											fill-pen linear (data/position=) 1 (data/dimension=/y) 90 1 1 ( data/color= * 0.6 + 128.128.128) ( data/color= ) (data/color= * 0.7 )
											box (pos: (data/position= + (data/dimension= * 0x1) - -2x10)) (data/position= + data/dimension= - 2x1) 2
	
											; border
											fill-pen none
											line-width 1
											pen  theme-knob-border-color
											box (data/position= ) (data/position= + data/dimension= - 1x1) 3


										]
									]
;									all [ data/hover?= compose [
;										; slight shadow
;										pen shadow
;										line-width 2
;										fill-pen none
;										box (data/position= + 2x2) (data/position= + data/dimension= - 2x0) 4
;										
;											pen white
;											line-width 1
;											fill-pen linear (data/position=) 1 (data/dimension=/y) 90 1 1 ((data/color= * 0.8) + (white * .3)) ((data/color= * 0.8) + (white * .3 )) ((data/color= * 0.8) + (white * .1))
;											box (data/position= + 2x2) (data/position= + data/dimension= - 3x3) 4
;											; shine
;											pen none
;											fill-pen (data/color= * 0.7 + 140.140.140.128)
;											box ( top-half  data/position= data/dimension= ) 4
;
;											; border
;											fill-pen none
;											line-width 1
;											pen  theme-knob-border-color
;											box (data/position= ) (data/position= + data/dimension= - 1x1) 5
;
;										]
;									]
									
									; default
									compose [
										(
											prim-knob 
												data/position= 
												data/dimension= - 1x1
												data/color=
												theme-knob-border-color
												'horizontal ;data/orientation=
												1
												4
										)
									]
								]
							)
							(
							either data/hover?= [
								compose [
									line-width 1
									pen none
									fill-pen (theme-glass-color + 0.0.0.200)
									;pen theme-knob-border-color
									box (data/position= + 3x3) (data/position= + data/dimension= - 3x3) 2
								]
							][[]]
							)
							line-width 2
							pen none ;(data/label-color=)
							fill-pen (data/label-color=)
							; label
							(prim-label/pad data/label= data/position= + 1x0 data/dimension= data/label-color= data/font= data/align=  data/padding=)
							
							
							
						]
							
						; controls layer
						;[]
						
						; overlay layer
						; like the bg, it may switched off, so don't depend on it.
						;[]
					]
				]
			]
			
			
			
			
			
			;-----------------
			;-        button-handler()
			;
			; this handler is used for testing purposes only. it is shared amongst all marbles, so its 
			; a good and memory efficient handler.
			;-----------------
			button-handler: func [
				event [object!]
				/local button
			][
				vin [{HANDLE BUTTON}]
				vprint event/action
				button: event/marble
				
				switch/default event/action [
					start-hover [
						fill* button/aspects/hover? true
					]
					
					end-hover [
						fill* button/aspects/hover? false
					]
					
					select [
						;print "button pressed"
						fill* button/aspects/selected? true
						;probe content* button/aspects/label
						;probe button/actions
						event/marble/valve/do-action event
						;ask ""
					]
					
					; successfull click
					release [
						fill* button/aspects/selected? false
						;do-action event
					]
					
					; canceled mouse release event
					drop no-drop [
						fill* button/aspects/selected? false
						;do-action event
					]
					
					swipe [
						fill* button/aspects/hover? true
						;do-action event
					]
				
					drop? [
						fill* button/aspects/hover? false
						;do-action event
					]
				
					focus [
;						event/marble/label-backup: copy content* event/marble/aspects/label
;						if pair? event/coordinates [
;							set-cursor-from-coordinates event/marble event/coordinates false
;						]
;						fill* event/marble/aspects/focused? true
					]
					
					unfocus [
;						event/marble/label-backup: none
;						fill* event/marble/aspects/focused? false
					]
					
					text-entry [
;						type event
					]
				][
					vprint "IGNORED"
				]
				
				; totally configurable end-user event handling.
				; not all actions are implemented in the actions, but this allows the user to 
				; add his own events AND his own actions and still work within the API.
				event/marble/valve/do-action event
				
				vout
				none
			]
			
						

			;-----------------
			;-        setup-style()
			;-----------------
			; a callback to extend anything in the marble AFTER Glass has finished with its own setup
			;
			; this is used by styles for their own custom data requirements.
			;
			; styles may also provide application setup hooks, but usually do so via extensions to the
			; the specification parser, using dialect()
			; 
			; some styles will also add default stream handlers (like viewports)
			;-----------------
			setup-style: func [
				marble
			][
				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/stylize()}]
				
				; just a quick stream handler for all marbles
				event-lib/handle-stream/within 'button-handler :button-handler marble
				vout
			]
		]
	]
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %style-button.r 
    date: 25-Jun-2010 
    version: 0.5.3 
    slim-name: 'style-button 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: STYLE-BUTTON
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: STYLE-LIST  v0.5.3
;--------------------------------------------------------------------------------

append slim/linked-libs 'style-list
append/only slim/linked-libs [


;--------
;-   MODULE CODE




;- slim/register/header
slim/register/header [
	; declare words so they stay bound locally to this module

	layout*: get in system/words 'layout
	
	

	;- LIBS
	to-color: none
	
	!glob: none
	glob-lib: slim/open/expose 'glob none [!glob to-color]
	
	marble-lib: slim/open 'marble none
	
	
	!plug: liquify*: content*: fill*: link*: unlink*: none
	liquid-lib: slim/open/expose 'liquid none [
		!plug 
		[liquify* liquify ] 
		[content* content] 
		[fill* fill] 
		[link* link] 
		[unlink* unlink] 
		[dirty* dirty]
	]
	
	
	prim-bevel: prim-x: prim-label: prim-list: prim-glass: none
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: none
	top-half: bottom-half: find-same: get-aspect: include: include-different: none
	sillica-lib: slim/open/expose 'sillica none [
		include
		include-different
		get-aspect
		find-same
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		prim-bevel
		prim-x
		prim-label
		prim-list
		prim-glass
		top-half
		bottom-half
	]
	epoxy-lib: epoxy: slim/open/expose 'epoxy none [!box-intersection]
	event-lib: slim/open 'event none
	

	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;

	;--------------------------------------------------------
	;-   
	;- !LIST[ ]
	!list: make marble-lib/!marble [
	
		;-    Aspects[ ]
		aspects: context [
			;-        offset:
			offset: -1x-1
			
			;-        focused?:
			focused?: false

			;-        hover?:
			hover?: false
			
			;-        selected?:
			selected?: false
			
			;-        color:
			; color of bg
			color: white * .8
			
			;- 		LIST SPECIFICS
			;-        list:
			list: make-bulk/records 3 [ "" [] "" ]
;			list: [
;				"New Brunswick123456789" 00
;				"New York" 11
;				"Montreal" 22 
;				"L.A." 33
;				"L.A." 37 ; tests similar labels in the list
;				"Paris" 44
;				"London 23iwuety eoitetoiu" 55
;				"Rome" 66
;				"Pekin" 77
;				"Chicago" 88
;				"Amsterdam" 99
;				"Monza" 1010
;				"Mexico City" 1111
;				"Bangkok" 1212
;			]
			
			
			
			;-        columns:
			; how many columns in list data?
			;
			; for now this is hard-set to 2, but in future versions, we will expand and allow several label columns.
			columns: 2
			
			
			;-        list-index:
			; at what item should the display start showing list items?
			list-index: 1
			
			
			;-        chosen:
			; this is the list of chosen items in the list.
			; note:  
			;     -items in this list MUST be the exact SAME strings as those in list (not similar copies)
			;     -this list is managed by the events, so don't expect it to stay as-is.
			;     -by default the list is single select but is can be switched to multi-select by setting multi-choose? to true in the !list object.
			;    
			chosen: []
			
			
			;-        leading:
			; space between lines.
			leading: 6
			
		]

		
		;-    Material[]
		material: make material [
			;-        fill-weight:
			; we benefit from extra vertical space.
			fill-weight: 1x1
			
			;-        visible-items:
			;
			; returns how many items CAN be shown in the list, not how many are currently visible.
			;
			; this is based on the list size, list/valve/list-font/size, list/valve/item-spacing, and dimension, but doesn't react to list-index.
			;
			; if length? of list is smaller than size of list-box, visible-items will shrink to it.
			; 
			visible-items: none
			
			
			
			;-        row-count:
			; returns the number of items in list.
			row-count: none
			
			
			
			;-        chosen-items:
			;
			; a version of list with only the chosen in it.
			;
			; it can be used directly as the source of another list !
			;
			chosen-items: none
			
			
		]
		
		
		;-    multi-choose?:
		multi-choose?: true
		
		
		;-    actions:
		; nothing by default
		actions: context [
			list-picked: func [event][
				;print "list action!"
				;print event/picked
				;probe event/picked-data
				;probe event/chosen
			]
		]
		
		
		;-    list-columns:
		list-columns: 2 ; eventually programmable
		
		
		;-    scroller:
		; stores the scroller we allocate for our own internal use.
		scroller: none
		
		
		;-    filter-mode-plug:
		; just a simple plug which stores chosen filter mode.
		; for now, only 'same is supported or really usefull.
		;
		; in special circumstance, though, you could require 'simple.
		filter-mode-plug: none
		
		
		;-    valve[ ]
		valve: make valve [
		
			type: '!marble
		
			;-        style-name:
			; used as a label for debugging and node browsing.
			style-name: 'list  
			
			
			
			
			;-        item-spacing:
			; how much space to add between items.  (not yet fully supported, some things are still hard coded to: 2)
			item-spacing: 2
			
			
			;-        glob-class:
			; defines the glob which will be built by each marble instance.
			;   glob-class/marble  is added automatically by setup.
			glob-class: make !glob [
				pos: none
				
				
				valve: make valve [
					; internal calculation vars
					p: none
					d: none
					e: none
					h?: none
					list: none
					highlight-color: 0.0.0.50
					
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup these will be stored within glob/input
						position !pair (random 200x200)
						dimension !pair (100x30)
						color !color  (random white)
						focused? !bool 
						hover? !bool 
						selected? !bool
						
						; list specific
						list !block ; tag pairs of "label" payload
						list-index !integer
						chosen !block ; one or more chosen items.
					]
					
					;-            glob/gel-spec:
					; different AGG draw blocks to use, one per layer.
					; these are bound and composed relative to the input being sent to glob at process-time.
					gel-spec: [
						; event backplane
						position dimension 
						[
							line-width 1 
							pen none 
							fill-pen (to-color gel/glob/marble/sid)
							box (data/position=) (data/position= + data/dimension= - 1x1)
						]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						position dimension color focused? selected? list list-index chosen
						[
							
							(
								d: data/dimension=
								p: data/position=
								e: d + p - 1x1
								;h?: data/hover?= 
								list: data/list=
								[]
							)
							
							; bg + border
;							line-width 1							
;							pen theme-border-color
;							fill-pen white
;							box (p) (e) 3

;							; top shadow
;							pen none
;							fill-pen linear (p + 0x1) 1 (5) 90 1 1 
;								(0.0.0.100) 
;								(0.0.0.200) 
;								(0.0.0.255 )
;							box (p + 0x1) (p + (d/x * 1x0) + 0x6) 3
;
;							;side shadows
;							fill-pen linear (p + 1x1) 1 (3) 0 1 1 
;								(0.0.0.180) 
;								(0.0.0.240) 
;								(0.0.0.240) 
;								(0.0.0.255 )
;							box (p + 1x1) (p + (d/y * 0x1) + 4x0) 3
;							
;							fill-pen linear (p + (d/x * 1x0 - 5x0)) 1 (3) 0 1 1 
;								(0.0.0.255 )
;								(0.0.0.240) 
;								(0.0.0.240) 
;								(0.0.0.180) 
;							box (p + (d/x * 1x0 - 5x0)) (p + d - 1x1) 3
							
							(
								;shadows
								prim-cavity/colors
									data/position= 
									data/dimension= - 1x1
									white
									theme-border-color
							)
							
							
							; labels
							pen none
							fill-pen black
							line-width 0.5
							(
								prim-list p + 2x2 d - 5x5 theme-list-font content* gel/glob/marble/aspects/leading list data/list-index= data/chosen= none black
							)
							
							; for debugging
;							pen 255.0.0
;							fill-pen none
;							box (p + 2x2) (e - 2x2)
						]
							
						; controls layer
						;[]
						
						; overlay layer
						; like the bg, it may switched off, so don't depend on it.
						;[]
					]
				]
			]
			
			
			;-----------------
			;-        item-from-coordinates()
			;
			; returns the index of item under coordinates
			;-----------------
			item-from-coordinates: func [
				list [object!]
				coordinates [pair!]
				/local i picked
			][
				vin [{glass/!} uppercase to-string list/valve/style-name {[} list/sid {]/item-from-coordinates()}]
				i: content* list/aspects/list-index
				
				v?? i
				; 2x4 is a hard-coded origin where drawing starts
				picked: second coordinates - 2x4
				picked: (to-integer (picked / (theme-list-font/size + content* list/aspects/leading)))
				picked: picked + i ;+ 2
				;v?? picked
				
				vout
				
				picked
			]
			
			
			
			
			
			
			
			;-----------------
			;-        find-row()
			;
			; return the row at the index of supplied item
			;
			; note: when supplying a string it must be the EXACT same string, cause a single list
			;       might have several items with the same label
			;
			;-----------------
			find-row: func [
				list [object!]
				item [string! integer!]
				/local items columns label-column row
			][
				vin [{glass/!} uppercase to-string list/valve/style-name {[} list/sid {]/find-item()}]
				items: content* list/aspects/list
				
				row: either string? item [
				;	item: pick items (item - 1 * columns + 1)
					column: any [
						get-bulk-property items 'label-column
						1
					]
					search-bulk-column/same/row items column item
				][
					; if item is larger than row count, none is returned
					get-bulk-row items item
				]

				vout				
				; we ignore invalid pick values
;				if item: find-same items item [
;					item
;				]

				row
			]
			
			
			;-----------------
			;-        choose-item()
			;
			; add the item (if its in list) to the chosen block.
			;
			; note:
			;     -if item doesn't exist its quietly ignored 
			;     -if item doesn't change the list, no liquid messaging occurs.
			;-----------------
			choose-item: func [
				list [object!]
				item [string! none!] "none clears the chosen list"
				/add "add this to chosen, don't replace it, only valid if list/multi-choose? = true "
				/local c l cplug
			][
				vin [{glass/!} uppercase to-string list/valve/style-name {[} list/sid {]/choose-item()}]
				cplug: get-aspect/plug list 'chosen 
				c: content* cplug
				l: get-aspect list 'list
				;v?? l
				;v?? item
				either none? item [
					clear c
					cplug/valve/notify cplug
				][
					if find-same l item [
						;vprint "exists"
						either all [
							add
							list/multi-choose?
						][
							;vprint "MULTI!"
							; only change list if item isn't already in it
							unless find-same c item [
								; multi-choose (add new item to chosen)
								include-different c item
								
								; make sure liquid notifies any linked or piped plugs
								cplug/valve/notify cplug
							]
						][
							;vprint "single choose"
							; only change list if item isn't already in it OR chosen has more than one item in it
							unless all [
								1 = length? c
								find-same c item
							][
								; single choose (replace any chosen by new item)
								clear c
								append c item
							
								; make sure liquid notifies any linked or piped plugs
								cplug/valve/notify cplug
							]
						]
					]
				]
				; print result
				;vprobe head c
				
				vout
			]
			
			
			;-----------------
			;-        pick-next()
			;
			; the list is automatically scrolled so that the item is visible
			;-----------------
			pick-next: func [
				list
				/wrap "cause the last item to chose the first"
				/data "returns the data row instead of the label"
				/local item  c l cplug spec list-spec row new-item blk
			][
				vin [{pick-next()}]
				cplug: get-aspect/plug list 'chosen 
				c: content* cplug
				l: get-aspect list 'list

				item: any [
					all [
						not empty? c
						last c
					]
					;pick l 2 ; if nothing is currently picked, get the first label.
				]
				
				
				list-spec: first l
				
				; get row data for current item
				blk: find-same l item
				
				new-item: any [
					all [
						blk
						pick blk: skip blk 3 1
					]
					; we are at end
					all [
						any [wrap  not blk]
						pick l 2
					]
				]
				
				if new-item [
					choose-item list new-item
					if data [
						if (blk: find-same l new-item) [
							row: copy/part blk 3
						]
						new-item: row
					]
				]
				vout
				new-item
			]
			
			;-----------------
			;-        pick-previous()
			;
			; the list is automatically scrolled so that the item is visible
			;-----------------
			pick-previous: func [
				list
				/wrap "cause the first item to chose the last"
				/data "returns the data row instead of the label"
				/local item  c l cplug spec list-spec row new-item blk
			][
				vin [{pick-previous()}]
				cplug: get-aspect/plug list 'chosen 
				c: content* cplug
				l: get-aspect list 'list

				item: any [
					all [
						not empty? c
						last c
					]
					;pick l 2 ; if nothing is currently picked, get the first label.
				]
				
				
				list-spec: first l
				
				; get row data for current item
				blk: find-same l item
				
				new-item: any [
					all [
						blk
						(index? blk) > 4
						pick blk: skip blk -3 1
					]
					; we are at head
					all [
						any [wrap  not blk]
						(length? l) > 4 ; no point in picking the same item again
						pick tail l -3
					]
				]
				
				if new-item [
					choose-item list new-item
					if data [
						if (blk: find-same l new-item) [
							row: copy/part blk 3
						]
						new-item: row
					]
				]
				
				vout
				new-item
			]
			
			
			
			
			
			
			
			;-----------------
			;-        list-handler()
			;
			;-----------------
			list-handler: func [
				event [object!]
				/local list picked i l data-col label-col
			][
				vin [{HANDLE LIST EVENTS}]
				vprint event/action
				list: event/marble
				switch/default event/action [
					start-hover [
						fill* list/aspects/hover? true
					]
					
					end-hover [
						fill* list/aspects/hover? false
					]
					
					select [
						;vprint "RESOLVING CHOSEN ITEM"
						if picked: item-from-coordinates list event/offset [
						;v?? picked
						
							if picked: find-row list picked [
								;probe content* list/aspects/chosen
								
								event-lib/queue-event make event compose/only [
									action: 'list-picked
									picked: (first picked)
									; we now return the whole row of list, since it may contain user data beyond
									; what the list requires.
									picked-data: (picked)
									chosen: (content* list/aspects/chosen)
								]
							]
						]
					]

					list-picked [
						; if list doesn't mave multi-choose? enabled, it will ignore /add and replace chosen.
						either event/control? [
							;vprint "-----------> MULTI CHOOSE"
							choose-item/add list event/picked
						][
							choose-item list event/picked
						]
					]
										
					; successfull click
					release [
						fill* list/aspects/selected? false
						;do-action event
					]
					
					; canceled mouse release event
					drop no-drop [
						fill* list/aspects/selected? false
						;do-action event
					]
					
					swipe [
						fill* list/aspects/hover? true
						;do-action event
					]
				
					drop? [
						fill* list/aspects/hover? false
						;do-action event
					]
					
					
					scroll focused-scroll [
						switch event/direction [
							pull [
								i: get-aspect event/marble 'list-index
								l: get-aspect event/marble 'list
								v: get-aspect/or-material event/marble 'visible-items
								if (i + v - 1) < (to-integer (0.5 * length? l)) [
									fill* event/marble/aspects/list-index i + event/amount
								]
							]
							
							push [
								i: get-aspect event/marble 'list-index
								if i > 1 [
									fill* event/marble/aspects/list-index i - event/amount
								]
							]
						]
					]
					
					
					focus [
;						event/marble/label-backup: copy content* event/marble/aspects/label
;						if pair? event/coordinates [
;							set-cursor-from-coordinates event/marble event/coordinates false
;						]
;						fill* event/marble/aspects/focused? true
					]
					
					unfocus [
;						event/marble/label-backup: none
;						fill* event/marble/aspects/focused? false
					]
					
					text-entry [
;						type event
					]
				][
					vprint "IGNORED"
				]
				
				; totally configurable end-user event handling.
				; not all actions are implemented in the actions, but this allows the user to 
				; add his own events AND his own actions and still work within the API.
				event/marble/valve/do-action event
				
				vout
				none
			]
			
			
			;-----------------
			;-        materialize()
			; 
			; <TO DO> make a purpose built epoxy plug for visible-items and instantiate it.
			;-----------------
			materialize: func [
				list
			][
				vin [{glass/!} uppercase to-string list/valve/style-name {[} list/sid {]/materialize()}]
				
				list/material/row-count: liquify* epoxy/!bulk-row-count
				
				; this plug expects to be linked, never piped
				;-           visible-items:
				list/material/visible-items: liquify*/with !plug [
					; we store a reference to the list in which this plug is used
					list-marble: list
					
					valve: make valve [
						type: 'list-visibility-calculator
						
						;-----------------
						;-                process()
						;-----------------
						process: func [
							plug
							data
							/local list dimension v leading
						][
							vin [{visibility-calculator/process()}]
							
							; just make sure we have a proper interface
							plug/liquid: either all [
								block? list: pick data 1
								pair? dimension: pick data 2
								integer? leading: pick data 3
							][
								v: plug/list-marble/valve
								to-integer min ( bulk-rows list)((dimension/y - 6) / (theme-list-font/size + leading))
							][
								0
							]
							;print ["visible-items: " plug/liquid]
							vout
						]
					]
				]
				
				list/material/chosen-items: liquify* epoxy/!bulk-filter
				list/filter-mode-plug: liquify*/fill !plug 'same
				
				
				vout
			]
			

			;-----------------
			;-        fasten()
			;-----------------
			fasten: func [
				list
			][
				vin [{glass/!} uppercase to-string list/valve/style-name {[} list/sid {]/fasten()}]
				
				link*/reset list/material/visible-items reduce [list/aspects/list list/material/dimension list/aspects/leading]
				link list/material/row-count list/aspects/list
				link list/material/row-count list/aspects/columns
				
				link*/reset list/material/chosen-items list/aspects/list
				link* list/material/chosen-items list/aspects/chosen
				link* list/material/chosen-items list/filter-mode-plug
				
				
				vout
			]
			
			
			
			;-----------------
			;-        specify()
			;
			; parse a specification block during initial layout operation
			;
			; can also be used at run-time to set values in the aspects block directly by the application.
			;
			; but be carefull, as some attributes are very heavy to use like frame sub-marbles, which will 
			; effectively trash their content and rebuild the content again, if used blindly, with the 
			; same spec block over and over.
			;
			; the marble we return IS THE MARBLE USED IN THE LAYOUT
			;
			; so the the spec block can be used to do many wild things, even change the 
			; marble type on the fly!!
			;-----------------
			specify: func [
				marble [object!]
				spec [block!]
				stylesheet [block!] "Required so stylesheet propagates in marbles we create"
				/local data pair-count tuple-count block-count
			][
				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/specify()}]
				
				pair-count: 0
				tuple-count: 0
				block-count: 0
				
				parse spec [
					any [
						copy data ['with block!] (
							;marble: make marble data/2
							;liquid-lib/reindex-plug marble
							do bind/copy data/2 marble 
							
						) | 
						'stiff (
							fill* marble/material/fill-weight 0x0
						) |
						'stretch set data pair! (
							fill* marble/material/fill-weight data
						) |
						set data tuple! (
							tuple-count: tuple-count + 1
							switch tuple-count [
								1 [set-aspect marble 'label-color data]
								2 [set-aspect marble 'color data]
							]
							
							set-aspect marble 'color data
						) |
						set data pair! (
							pair-count: pair-count + 1
							switch pair-count [
								1 [	fill* marble/material/min-dimension data ]
								2 [	set-aspect marble 'offset data ]
							]
						) |
						set data string! (
							fill* marble/aspects/label data
						) |
						set data block! (
							block-count: block-count + 1
							switch block-count [
								1 [
									; lists support 3 columns, one being label, another options and the last being data.
									; options will change how the item is displayed (bold, strikethru, color, etc).
									fill* marble/aspects/list make-bulk/records 3 data
								]
								2 [
									if object? get in marble 'actions [
										marble/actions: make marble/actions [list-picked: make function! [event] bind/copy data marble]
									]
								]
							]
						) |
						skip 
					]
				]
				
				vout
				marble
			]
			
			
			

			;-----------------
			;-        setup-style()
			;-----------------
			; a callback to extend anything in the marble AFTER Glass has finished with its own setup
			;
			; this is used by styles for their own custom data requirements.
			;
			; styles may also provide application setup hooks, but usually do so via extensions to the
			; the specification parser, using dialect()
			; 
			; some styles will also add default stream handlers (like viewports)
			;-----------------
			setup-style: func [
				list
			][
				vin [{glass/!} uppercase to-string list/valve/style-name {[} list/sid {]/stylize()}]
				
				; just a quick stream handler for our list
				event-lib/handle-stream/within 'list-handler :list-handler list
				
				
				vout
			]
		]
	]
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %style-list.r 
    date: 25-Jun-2010 
    version: 0.5.3 
    slim-name: 'style-list 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: STYLE-LIST
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: STYLE-SCROLLER  v0.8.1
;--------------------------------------------------------------------------------

append slim/linked-libs 'style-scroller
append/only slim/linked-libs [


;--------
;-   MODULE CODE



;- slim/register/header
slim/register/header [
	; declare words so they stay bound locally to this module

	layout*: get in system/words 'layout
	
	

	;- LIBS
	to-color: none
	
	!glob: none
	glob-lib: slim/open/expose 'glob none [!glob to-color]
	
	marble-lib: slim/open 'marble none
	
	
	!plug: liquify*: content*: fill*: link*: unlink*: none
	liquid-lib: slim/open/expose 'liquid none [
		!plug 
		[liquify* liquify ] 
		[content* content] 
		[fill* fill] 
		[link* link] 
		[unlink* unlink] 
		[dirty* dirty]
	]
	
	
	prim-bevel: prim-x: prim-label: prim-knob: prim-recess: none
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: none
	top-half: bottom-half: none
	sillica-lib: slim/open/expose 'sillica none [
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		prim-bevel
		prim-x
		prim-label
		prim-knob
		prim-recess
		prim-cavity
		top-half
		bottom-half
	]
	epoxy-lib: slim/open 'epoxy none
	event-lib: slim/open 'event none

	

	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;

	;--------------------------------------------------------
	;-   
	;- !SCROLLER[ ]
	!scroller: make marble-lib/!marble [
	
	
		;-    knob-selected-event:
		; when user selects the knob, we store its event, for reference while dragging
		knob-selected-event: none
		
		
		;-    orientation:
		; when the orientation is set to none.... fasten will look at parent 
		; and orient itself in the opposite direction... so a vertical frame will result in a horizontal scroller
		;orientation: none  ; can be none, 'vertical or 'horizontal
	
		
		;-    stiff?:
		stiff?: none
		
	
		;-    Aspects[ ]
		aspects: context [
			offset: -1x-1
			
			;-        focused?:
			; some scrollers can be highlighted
			focused?: false
			
			;-        pressed?:
			selected?: false
			
			;-       hover?:
			hover?: none
	
			;-        color:
			color: white * .8


			;-        bg-color:
			;bg-color: black
			
			
			;-        minimum:
			minimum: 1
			
			
			;-        maximum:
			maximum: 100
			
			
			;-        visible:
			visible: 5


			;-        size:
			size: 20x20
			

			;-        value:
			; the current value of the scroller within the range
			; if min or max are decimal, this will also be a decimal.
			; otherwise value will set itself to an integer
			;
			; the material has a plug called index, its piped with the value.
			; the value has a purify method which rounds the index to its own range type.
			value: 3
			
			
		]


	



		
		;-    Material[]
		material: make material [
		
			;-        knob-position:
			; offset of knob in pixels
			knob-position: 0x0
			
			
			;-        knob-offset:
			; the pixel offset of the knob.  this is bridged with the 
			; value aspect.
			;
			; note that the channel used is called: 'offset
			;
			; the aspects will use the 'value channel.
			;
			; this is materialized as a epoxy/offset-value-bridge plug.
			;
			; fasten will attach aspects/value to the pipe server, and link the min/max/dimension to appropriate plugs.
			knob-offset: none
			
			
			;-        scroll-space:
			; 
			; the available space which the scroller knob has for movement
			;
			; basically:  (dimension - knob-dimension)
			scroll-space: 0x0
			
			
			
			;-        scroll-range:
			; this is the maximum amount to return in scroll value.
			;
			; basically maximum - visible
			scroll-range: 1
			
			
			
			;-        knob-scale:
			; size of the knob along its orientation  
			knob-scale: 100x100
			
			
			;-        knob-dimension:
			; final calculated size of the knob in pixels 
			knob-dimension: 100x100
			
			
			
			;-        index:
			; like the value, but internal
			index: none
			
			
			
			;-        orientation:
			; in what orientation will the scroller work.
			; its in material, because the fasten call will set this depending on
			; parent frame, if its set to 'auto when fasten looks at it.
			orientation: 'auto
			
			
			
			;-        min-dimension
			min-dimension: 20x20
		]
		
		
		
		
			
		
		;-    valve[ ]
		valve: make valve [
		
			type: '!marble
		
			;-        style-name:
			; used as a label for debugging and node browsing.
			style-name: 'scroller  
			
			
			
			
			;-        glob-class:
			; defines the glob which will be built by each marble instance.
			;   glob-class/marble  is added automatically by setup.
			glob-class: make !glob [
				pos: none
				
				valve: make valve [
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup these will be stored within glob/input
						position !pair (random 200x200)
						dimension !pair (100x30)
						color !color  (random white)
						;label-color !color  (random white)
						;label !string ("")
						focused? !bool
						hover? !bool
						selected? !bool
						knob-position !pair
						knob-dimension !pair ( 100x100)
						knob-position !pair (0x0)
						orientation !word
					]
					
					;-            glob/gel-spec:
					; different AGG draw blocks to use, one per layer.
					; these are bound and composed relative to the input being sent to glob at process-time.
					gel-spec: [
						; event backplane
						position dimension 
						[
							line-width 1 
							pen none 
							fill-pen (to-color gel/glob/marble/sid) 
							box (data/position=) (data/position= + data/dimension= - 1x1)
						]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						position dimension color hover? focused? selected? knob-position knob-dimension orientation
						[
							
							; BG
							(
								prim-recess 
									data/position= 
									data/dimension= - 1x1
									theme-recess-color
									theme-border-color
									data/orientation=
							)
							(
								prim-cavity/colors
									data/position= 
									data/dimension= - 1x1
									none
									theme-border-color
							)
							
							
							; KNOB
							(
								prim-knob/grit 
									data/knob-position= + 1x1 
									data/knob-dimension= - 3x3
									none
									none ;theme-knob-border-color * 0.5
									data/orientation=
									max 0 (data/dimension=/y - data/knob-dimension=/y - data/knob-position=/y) + 10
									3
							)
							
							(
								either data/hover?= [
									compose [
										line-width 1
										fill-pen (theme-glass-color + 0.0.0.220)
										pen theme-knob-border-color
										pen none
										box (data/knob-position= + 3x3) (data/knob-position= + data/knob-dimension= - 3x3) 2
									]
								][[]]
							)
							
						]
							
						; controls layer
						;[]
						
						; overlay layer
						; like the bg, it may switched off, so don't depend on it.
						;[]
					]
				]
			]
			
			
			
			
			;-----------------
			;-        scroller-HANDLER()
			;-----------------
			scroller-handler: func [
				event [object!]
				/local scroller kpos ksize kend action val
			][
				vin [{HANDLE SCROLLER}]
				vprint event/action
				scroller: event/marble
				
				switch/default event/action [
					start-hover [
						fill* scroller/aspects/hover? true
					]
					
					end-hover [
						fill* scroller/aspects/hover? false
					]
					
					hover [
						;prin "."
						
						kpos: content* scroller/material/knob-position 
						kpos: kpos - content* scroller/material/position
						ksize: content* scroller/material/knob-dimension
						kend: kpos + ksize
						either within? event/offset kpos ksize  [
							unless content* scroller/aspects/hover? [
								fill* scroller/aspects/hover? true
							]
						][
							if content* scroller/aspects/hover? [
								fill* scroller/aspects/hover? false
							]
						
						]
					]
					
					select [
						;print "scroller pressed"
						fill* scroller/aspects/selected? true
						;probe content* scroller/aspects/label
						;probe scroller/actions
						
						kpos: content* scroller/material/knob-position 
						kpos: kpos - content* scroller/material/position
						ksize: content* scroller/material/knob-dimension
						kend: kpos + ksize
						action: any [
							all [within? event/offset kpos ksize 'select-knob]
							all [event/offset/y < kpos/y 'select-pull]
							all [event/offset/y >= kend/y 'select-push]
						]
						switch action [
							select-knob [
								;print "CLICKED ON KNOB"
								scroller/knob-selected-event: make event [knob-offset-start: content* scroller/material/knob-offset]
							]
							
							select-pull [
								vprint "PULL KNOB UP" 
							
							]
							
							select-push [
								vprint "PULL KNOB DOWN"
							]
						]
						
						event/marble/valve/do-action event
						;ask ""
					]
					
					; successfull click
					release [
						fill* scroller/aspects/selected? false
						scroller/knob-selected-event: none
						;do-action event
					]
					
					; canceled mouse release event
					drop no-drop [
						fill* scroller/aspects/selected? false
						;do-action event
					]
					
					swipe drop? [
						;fill* scroller/aspects/hover? true
						if scroller/knob-selected-event [
							;probe event/drag-delta
							;probe event/drag-start
							
							fill* scroller/material/knob-offset scroller/knob-selected-event/knob-offset-start + event/drag-delta
						]
						;do-action event
					]
					
					scroll [
						val: content* scroller/aspects/value
						switch event/direction [
							push [
								fill* scroller/aspects/value val - 1
							]
							
							pull [
								fill* scroller/aspects/value val + 1
								
							]
						]
					]
;					drop? [
;						;fill* scroller/aspects/hover? false
;						;do-action event
;					]
				
					focus [
;						event/marble/label-backup: copy content* event/marble/aspects/label
;						if pair? event/coordinates [
;							set-cursor-from-coordinates event/marble event/coordinates false
;						]
;						fill* event/marble/aspects/focused? true
					]
					
					unfocus [
;						event/marble/label-backup: none
;						fill* event/marble/aspects/focused? false
					]
					
					text-entry [
;						type event
					]
				][
					vprint "IGNORED"
				]
				
				; totally configurable end-user event handling.
				; not all actions are implemented in the actions, but this allows the user to 
				; add his own events AND his own actions and still work within the API.
				event/marble/valve/do-action event
				
				vout
				none
			]
			
			
			
			;-----------------
			;-        freeze-backplane()
			;-----------------
			freeze-backplane: func [
				scroller
			][
				vin [{freeze-backplane()}]
				scroller/glob/layers/1/freeze scroller/glob/layers/1
				vout
			]
			
			
			;-----------------
			;-        thaw-backplane()
			;-----------------
			thaw-backplane: func [
				scroller
			][
				vin [{thaw-backplane()}]
				scroller/glob/layers/1/thaw scroller/glob/layers/1
				vout
			]
			
			
						

			;-----------------
			;-        setup-style()
			;-----------------
			; a callback to extend anything in the marble AFTER Glass has finished with its own setup
			;
			; this is used by styles for their own custom data requirements.
			;
			; styles may also provide application setup hooks, but usually do so via extensions to the
			; the specification parser, using dialect()
			; 
			; some styles will also add default stream handlers (like viewports)
			;-----------------
			setup-style: func [
				scroller
			][
				vin [{glass/!} uppercase to-string scroller/valve/style-name {[} scroller/sid {]/stylize()}]
				
				; just a quick stream handler for all scrollers
				event-lib/handle-stream/within 'scroller-handler :scroller-handler scroller
				vout
			]
			
			
			;-----------------
			;-        materialize()
			;-----------------
			materialize: func [
				scroller
				/local ko mtrl
			][
				vin [{glass/!} uppercase to-string scroller/valve/style-name {[} scroller/sid {]/materialize()}]
				;epoxy/von
				;liquid-lib/von
				
				mtrl: scroller/material
				
				
				ko: mtrl/knob-offset: liquify* epoxy-lib/!offset-value-bridge
				ko/valve/fill/channel ko 0x33 'offset


				mtrl/knob-position: liquify* epoxy-lib/!pair-add
				
				mtrl/knob-dimension: liquify* epoxy-lib/!to-pair 
				mtrl/knob-scale: liquify* epoxy-lib/!range-scale

				
				mtrl/orientation: liquify*/fill !plug mtrl/orientation

				mtrl/scroll-space: liquify* epoxy-lib/!pair-subtract
				mtrl/scroll-range: liquify* epoxy-lib/!range-sub

				
				
				;ask "!!!"
				;liquid-lib/voff
				;epoxy/voff
				vout
			]
			
			


		
			;-----------------
			;-        dialect()
			;
			; this uses the exact same interface as specify but is meant for custom marbles to 
			; change the default dialect.
			;
			; note that the default dialect is still executed, so you may want to "undo" what
			; it has done previously.
			;
			;-----------------
			dialect: func [
				marble [object!]
				spec [block!]
				stylesheet [block!] "Required so stylesheet propagates in marbles we create"
				/local data img-count icon
			][
				vin [{dialect()}]
				img-count: 1
				
				;print "!"
				
				parse spec [
					any [
						'stiff (
							marble/stiff?:  0x0
						)
						| skip
					]
				]

				vout
			]			



			
			;-----------------
			;-        fasten()
			;-----------------
			fasten: func [
				scroller
				/local value mtrl aspects vertical? 
			][
				vin [{fasten()}]
								
				mtrl: scroller/material
				aspects: scroller/aspects
				
				;-----------
				; specify orientation based on frame, if its not explictely set.
				; note that because the orientation depends on fastening and that this isn't
				; a liquified process, the layout method is an attribute of the frame directly.
				if 'auto = content* mtrl/orientation [
					if in scroller/frame 'layout-method [
						if scroller/frame/layout-method = 'column [
							fill* mtrl/orientation 'horizontal
							;vertical?: false
						]
						if scroller/frame/layout-method = 'row [
							fill* mtrl/orientation 'vertical
							;vertical?: true
						]
					]
				]
				
				vertical?: 'vertical = content* mtrl/orientation

				
				; if orientation was set to 'auto
				fill* mtrl/fill-weight any [ scroller/stiff? either vertical? [0x1][1x0]]
					
				
				; setup knob size & related
				link* mtrl/knob-scale aspects/minimum
				link* mtrl/knob-scale aspects/maximum
				link* mtrl/knob-scale aspects/visible
				link* mtrl/knob-scale mtrl/dimension
				
				either vertical? [
					link* mtrl/knob-dimension mtrl/dimension
					link* mtrl/knob-dimension mtrl/knob-scale
				][
					link* mtrl/knob-dimension mtrl/knob-scale
					link* mtrl/knob-dimension mtrl/dimension
				]
				
				link* mtrl/scroll-space mtrl/dimension
				link* mtrl/scroll-space mtrl/knob-dimension
				
				link* mtrl/scroll-range aspects/maximum
				link* mtrl/scroll-range aspects/visible
				
				
				;------------
				; setup value & knob-offset BRIDGE
				value: aspects/value
				value/valve/attach/to value mtrl/knob-offset 'value
				
				value/valve/link/pipe-server value aspects/minimum
				value/valve/link/pipe-server value mtrl/scroll-range
				value/valve/link/pipe-server value mtrl/scroll-space
				value/valve/link/pipe-server value mtrl/orientation
				
				
				; setup knob position (knob offset + marble position)
				link* mtrl/knob-position mtrl/position 
				link* mtrl/knob-position mtrl/knob-offset 
				
				
				; just a bridge test
				;fill* aspects/value 210
				;fill* aspects/minimum 10
				;fill* aspects/maximum 30
				
				;fill* aspects/visible 10
				
				;link*/exclusive mtrl/min-dimension aspects/size
				
				
				;probe content value
				
				;ask "---"
				
				;pipe-server
				vout
			]
		]
	]
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %style-scroller.r 
    date: 14-Jan-2010 
    version: 0.8.1 
    slim-name: 'style-scroller 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: STYLE-SCROLLER
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: STYLE-CHOICE  v0.8.0
;--------------------------------------------------------------------------------

append slim/linked-libs 'style-choice
append/only slim/linked-libs [


;--------
;-   MODULE CODE




;- slim/register/header
slim/register/header [
	; declare words so they stay bound locally to this module


	;- LIBS
	to-color: none
	
	!glob: none
	glob-lib: slim/open/expose 'glob none [!glob to-color]
	
	popup-lib: slim/open 'popup none
	event-lib: slim/open 'event none
	
	
	!plug: liquify*: content*: fill*: link*: unlink*: none
	liquid-lib: slim/open/expose 'liquid none [
		!plug 
		[liquify* liquify ] 
		[content* content] 
		[fill* fill] 
		[link* link] 
		[unlink* unlink] 
		[dirty* dirty]
	]
	
	
	prim-bevel: prim-x: prim-label: prim-knob: none
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: none
	top-half: bottom-half: none
	sl: slim/open/expose 'sillica none [
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		prim-bevel
		prim-x
		prim-label
		prim-knob
		top-half
		bottom-half
	]
	epoxy-lib: slim/open/expose 'epoxy none [!box-intersection]

	

	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;

	;--------------------------------------------------------
	;-   
	;- !CHOICE[ ]
	!choice: make popup-lib/!popup [
	
		;-    drop-list:
		; stores a reference to our internal drop-list, within fasten.
		drop-list: none
		
		;-    max-size:
		max-size: 20000x300



		;-    Aspects[ ]
		aspects: make aspects [
			;-        label:
			label: "choice"
			
			
			;-        items:
			; items used by drop-down is a bulk. if no label-column: is specified in header,
			; column 1 is assumed.
			;
			; if none, the choice simply doesn't show a selection drop down.
			items: none
			
			
			;-        picked-item:
			; which item is selected in choice.
			;
			; usefull to pipe other labels to it.
			picked-item: none
			
		]
		
		;-    valve[ ]
		valve: make valve [
			;-        style-name:
			; used as a label for debugging and node browsing.
			style-name: 'choice  
			
			
			;-        label-font:
			; font used by the gel.
			label-font: theme-knob-font


			;-        overlay-glob-class
			overlay-glob-class: [
				column tight with [
					fill* aspects/color white 
					fill* aspects/frame-color black
					fill* material/border-size 3x3
				][
					droplist with [
						fill* aspects/items make-bulk/records 3 ["one" [] 1 "two" [] 2 "three" [] 3] 
						fill* material/min-dimension 200x100
					]
					;button "test" [event-lib/queue-event compose [viewport: event/viewport action: 'remove-overlay]]
				]
			]
		
		
			;-        glob-class:
			; defines the glob which will be built by each marble instance.
			;   glob-class/marble  is added automatically by setup.
			glob-class: make !glob [
				pos: none
				
				valve: make valve [
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup these will be stored within glob/input
						position !pair (random 200x200)
						dimension !pair (100x30)
						color !color  (random white)
						label-color !color  (random white)
						label !string ("")
						focused? !bool
						hover? !bool
						selected? !bool
					]
					
					;-            glob/gel-spec:
					; different AGG draw blocks to use, one per layer.
					; these are bound and composed relative to the input being sent to glob at process-time.
					gel-spec: [
						; event backplane
						position dimension 
						[
							line-width 1 
							pen none 
							fill-pen (to-color gel/glob/marble/sid) 
							box (data/position=) (data/position= + data/dimension= - 1x1)
						]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						position dimension color label-color label hover? focused? selected?
						[
							
							(	;draw bg and highlight border?
								any [
									all [ 
										data/hover?= data/selected?= compose [
											; bg color
											pen none
											line-width 0
											fill-pen linear (data/position=) 1 (data/dimension=/y) 90 1 1 ( data/color= * 0.6 + 128.128.128) ( data/color= ) (data/color= * 0.7 )
											box (data/position= + 1x1) (data/position= + data/dimension= - 1x1) 4
	
											; shine
											pen none
											fill-pen (data/color= * 0.7 + 140.140.140.128)
											box ( top-half  data/position= data/dimension= ) 4
											
											;inner shadow
											pen shadow ; 0.0.0.50
											line-width 2
											fill-pen none
											box (data/position= + 1x1) (data/position= + data/dimension= - 2x2) 4
	
											pen none
											line-width 0
											fill-pen linear (data/position=) 1 (data/dimension=/y) 90 1 1 ( data/color= * 0.6 + 128.128.128) ( data/color= ) (data/color= * 0.7 )
											box (pos: (data/position= + (data/dimension= * 0x1) - -2x10)) (data/position= + data/dimension= - 2x1) 4
	
											; border
											fill-pen none
											line-width 1
											pen  theme-knob-border-color
											box (data/position= ) (data/position= + data/dimension= - 1x1) 4


										]
									]
;									all [ data/hover?= compose [
;										; slight shadow
;										pen shadow
;										line-width 2
;										fill-pen none
;										box (data/position= + 2x2) (data/position= + data/dimension= - 2x0) 4
;										
;											pen white
;											line-width 1
;											fill-pen linear (data/position=) 1 (data/dimension=/y) 90 1 1 ((data/color= * 0.8) + (white * .3)) ((data/color= * 0.8) + (white * .3 )) ((data/color= * 0.8) + (white * .1))
;											box (data/position= + 2x2) (data/position= + data/dimension= - 3x3) 4
;											; shine
;											pen none
;											fill-pen (data/color= * 0.7 + 140.140.140.128)
;											box ( top-half  data/position= data/dimension= ) 4
;
;											; border
;											fill-pen none
;											line-width 1
;											pen  theme-knob-border-color
;											box (data/position= ) (data/position= + data/dimension= - 1x1) 5
;
;										]
;									]
									
									; default
									compose [
										(
											prim-knob 
												data/position= 
												data/dimension= - 1x1
												none
												theme-knob-border-color
												'horizontal ;data/orientation=
												1
												4
										)
									]
								]
							)
							
							(
							either data/hover?= [
								compose [
									line-width 1
									pen none
									fill-pen (theme-glass-color + 0.0.0.220)
									;pen theme-knob-border-color
									box (data/position= + 3x3) (data/position= + data/dimension= - 3x3) 2
								]
							][[]]
							)							
							line-width 0
							;pen (data/label-color=)
							fill-pen none 
							pen (theme-glass-color + 0.0.0.150)
							(sl/prim-arrow (data/position= + (data/dimension= * 1x0) - 10x-4 + ((data/dimension=/y * 0x1 / 2) ) ) 10x9 'bullet 'down)
							; label
							;clip (data/position= + 2x2) (data/position= + data/dimension= - 3x3)
							pen none
							fill-pen (data/label-color=)
							(prim-label data/label= data/position= + 6x0 data/dimension= data/label-color= theme-small-knob-font 'left)
							
							;clip none
							
							
						]
							
						; controls layer
						;[]
						
						; overlay layer
						; like the bg, it may switched off, so don't depend on it.
						;[]
					]
				]
			]
			
			
			;-----------------
			;-        fasten()
			;-----------------
			fasten: func [
				choice
				/lbl
			][
				vin [{glass/!} uppercase to-string choice/valve/style-name {[} choice/sid {]/fasten()}]
				vprint "FASTEN CHOICE"
				;lbl: content* choice/aspects/label
				
				;v?? lbl
				
				choice/drop-list: choice/overlay-glob/collection/1/collection/1
				
				choice/drop-list/controled-by: choice
				
				choice/aspects/items: choice/drop-list/aspects/items
				choice/aspects/picked-item: choice/drop-list/aspects/picked-item
				
				
				link*/reset choice/aspects/label choice/aspects/picked-item
				
				
				
				;fill* choice/aspects/picked-item "caca"
				
				;vprobe content* choice/aspects/label
				vout
			]
			
			
			
			;-----------------
			;-        specify()
			;
			; parse a specification block during initial layout operation
			;
			; can also be used at run-time to set values in the aspects block directly by the application.
			;
			; but be carefull, as some attributes are very heavy to use like frame sub-marbles, which will 
			; effectively trash their content and rebuild the content again, if used blindly, with the 
			; same spec block over and over.
			;
			; the marble we return IS THE MARBLE USED IN THE LAYOUT
			;
			; so the the spec block can be used to do many wild things, even change the 
			; marble type on the fly!!
			;-----------------
			specify: func [
				marble [object!]
				spec [block!]
				stylesheet [block!] "Required so stylesheet propagates in marbles we create"
				/local data pair-count tuple-count block-count drop-list
			][
				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/specify()}]
				drop-list: marble/overlay-glob/collection/1/collection/1
				
				
				pair-count: 0
				tuple-count: 0
				block-count: 0
				parse spec [
					any [
						copy data ['with block!] (
							;marble: make marble data/2
							;liquid-lib/reindex-plug marble
							do bind/copy data/2 marble 

						) | 
						'stiff (
							fill* marble/material/fill-weight 0x0
						) |
						set data tuple! (
							tuple-count: tuple-count + 1
							switch tuple-count [
								1 [set-aspect marble 'label-color data]
								2 [set-aspect marble 'color data]
							]
							
							set-aspect marble 'color data
						) |
						set data pair! (
							pair-count: pair-count + 1
							switch pair-count [
								1 [	fill* marble/material/min-dimension data]
								2 [	set-aspect marble 'offset data ]
							]
						) |
						set data string! (
							fill* drop-list/aspects/picked-item data
						) |
						set data block! (
							block-count: block-count + 1
							switch block-count [
								1 [
									fill* drop-list/aspects/items make-bulk/records 3 data
								]
								2 [
									if object? get in drop-list 'actions [
										drop-list/actions: make drop-list/actions [
											pick-item: make function! [event] bind/copy data drop-list
										]
									]
								]
							]
						) |
						skip 
					]
				]
				vout
				marble
			]			
		]
	]
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %style-choice.r 
    date: 23-Jun-2010 
    version: 0.8.0 
    slim-name: 'style-choice 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: STYLE-CHOICE
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: POPUP  v0.1.1
;--------------------------------------------------------------------------------

append slim/linked-libs 'popup
append/only slim/linked-libs [


;--------
;-   MODULE CODE




;- slim/register/header
slim/register/header [
	; declare words so they stay bound locally to this module

	layout*: get in system/words 'layout
	
	

	;- LIBS
	to-color: none
	
	!glob: none
	glob-lib: slim/open/expose 'glob none [!glob to-color]
	marble-lib: slim/open 'marble none
	
	
	!plug: liquify*: content*: fill*: link*: unlink*: none
	liquid-lib: slim/open/expose 'liquid none [
		!plug 
		[liquify* liquify ] 
		[content* content] 
		[fill* fill] 
		[link* link] 
		[unlink* unlink] 
		[dirty* dirty]
	]
	
	
	prim-bevel: prim-x: prim-label: prim-knob: none
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: none
	top-half: bottom-half: none
	sl: slim/open/expose 'sillica none [
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		prim-bevel
		prim-x
		prim-label
		prim-knob
		top-half
		bottom-half
	]
	epoxy-lib: slim/open/expose 'epoxy none [!box-intersection]
	event-lib: slim/open 'event none
	frame-lib: slim/open 'frame none
	

	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;

	;--------------------------------------------------------
	;-   
	;- !POPUP[ ]
	!popup: make marble-lib/!marble [
	
		;-    Aspects[ ]
		aspects: make aspects [
			
			;-        focused?:
			; some popups can be highlighted (ex: ok/cancel in requestors)
			focused?: false
			
			;-        pressed?:
			selected?: false
			
		
			;-        label:
			label: "popup"
			
			
			;-        color:
			color: theme-knob-color


			;-        label-color:
			label-color: black
			
			
		]

		
		;-    Material[]
		material: make material [
		
			;-        popped-up?:
			; (read only)
			;
			; will be managed by events, cannot be used as a switch to activate the overlay.
			;
			; this is mainly used for our glob's gel spec or other tricks which require to react
			; to popup state changing (maybe another marble wants to reflect the popup state).
			;
			; use reveal() to setup the popup within the overlay
			; use conceal() to remove it from the overlay
			popped-up?: none
			
			
		]
		
		
		
		;-    overlay-glob:
		;
		; this stores the liquified and faceted glob which will be used in the overlay.
		;
		; each instance, MUST have its own private copy of this glob, which is usually linked 
		; in position (at least) to its popup aspects/material.
		;
		; you are totally free to implement this glob as you wish (as long at it can be used in
		; glass as an interface element normally).
		overlay-glob: none
		
		
		;-    overlay-scroll-frame:
		;
		; we only create the scrollframe on demand.
		overlay-scroll-frame: none
		
		;-    max-size:
		max-size: 20000x20000
		
		
		
		;-    valve[ ]
		valve: make valve [
			;-        style-name:
			; used as a label for debugging and node browsing.
			style-name: 'popup  
			
			
			;-        label-font:
			; font used by the gel.
			label-font: theme-knob-font
			


			;-        overlay-glob-class:
			;
			; this attribute is special in that if its a block, we'll call a layout on it
			; as part of the default materialize setup.
			;
			; if its a marble, it just liquifies it directly, if it's none, you are
			; expected to build your overlay manually within materialize.
			;
			overlay-glob-class: [column [button "pop!"]]



			;-        glob-class:
			; defines the glob which will be built by each marble instance.
			;   glob-class/marble  is added automatically by setup.
			glob-class: make !glob [
				pos: none
				
				valve: make valve [
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup these will be stored within glob/input
						position !pair (random 200x200)
						dimension !pair (100x30)
						color !color  (random white)
						label-color !color  (random white)
						label !string ("")
						focused? !bool
						hover? !bool
						selected? !bool
						popped-up? !bool ; if true, means that overlay is active.
					]
					
					;-            glob/gel-spec:
					; different AGG draw blocks to use, one per layer.
					; these are bound and composed relative to the input being sent to glob at process-time.
					gel-spec: [
						; event backplane
						position dimension 
						[
							line-width 1 
							pen none 
							fill-pen (to-color gel/glob/marble/sid) 
							box (data/position=) (data/position= + data/dimension= - 1x1)
						]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						position dimension color label-color label hover? focused? selected?
						[
							; this is a simple base class... it isn't meant to be used as-is,
							; but this default gel-spec can be used by many pop-ups anyways.
							(
								prim-knob 
									data/position= 
									data/dimension= - 1x1
									none
									theme-knob-border-color
									'horizontal ;data/orientation=
									1
									6
							)
							
							
							line-width 0.5
							pen (data/label-color=)
							fill-pen (data/label-color=)
							; label
							(prim-label data/label= data/position= + 1x0 data/dimension= data/label-color= none 'center)
							
							
							
						]
							
						; controls layer
						;[]
						
						; overlay layer
						; like the bg, it may switched off, so don't depend on it.
						;[]
					]
				]
			]
			
			
			
			;-----------------
			;-        reveal()
			;
			; signals glass to put our popup glob in the overlay
			;
			; note that the overlay is managed via the stream, not function calls.
			;
			; the main reason is that someone in the event stream may want to react to
			; overlay being shown or hidden.
			;
			; one example is the window even-handler which triggers events differently  
			; based on an overlay being live or not.
			;
			; because the stream is a system which any marble may link itself into
			; they can react based on this information.
			;
			; another reason is that as a marble, we have no clue as to who or what
			; manages an overlay... all we know is that someone will pick it up.
			;
			; this forces popup use to be explicitely managed by glass, and not by some
			; stray user-built hack which won't remain future proof.
			;
			; currently, there is no explicit control as to where the popup appears, 
			; but that will change at some point.
			;
			; also, window bounds checking might eventually be enabled directly by the
			; reveal function,  displacing and/or resizing the popup based on if it fits
			; within the window or not.
			;
			; also, some functions will be built which allow a popup marble to perform
			; window bounds management manually, possibly switching between different 
			; setups based on size constraints.
			;-----------------
			reveal: func [
				popup [object!] "marble which wants to reveal its popup"
				event [object!]
				/local win-size pop-size pop-pos sf
			][
				vin [{glass/popup/reveal()}]
				if object? popup/overlay-glob [
					vprint "READY TO POP!"
					; verify out of bounds
					pop-size: content* popup/overlay-glob/material/dimension
					win-size: content* event/viewport/material/dimension
					pop-pos: event-lib/offset-to-coordinates popup 0x0
					v?? win-size
					v?? pop-size
					v?? pop-pos
					
					either all [
						pop-size/y < win-size/y
						pop-size/y < popup/max-size/y
					][
						; make sure we discard ourself from scrollframe.
						
						vprint "--->"
						if object? popup/overlay-glob/frame [
							print "UNLINK FROM SCROLLFRAME!"
							popup/overlay-glob/frame/valve/gl-discard popup/overlay-glob/frame popup/overlay-glob
						]
						
						vprobe type? popup/overlay-glob/frame
					;either false [
						if (pop-pos/y + pop-size/y) > win-size/y [
							pop-pos/y: win-size/y - pop-size/y
						]
						if (pop-pos/x + pop-size/x) > win-size/x [
							pop-pos/x: win-size/x - pop-size/x - 5
						]

					; set popup position
						fill* popup/overlay-glob/material/position pop-pos
						fill* popup/overlay-glob/material/dimension pop-size
						
						event-lib/queue-event make event [
							action: 'add-overlay
							; the glob we want to overlay
							frame: popup/overlay-glob
							
							; the event to trigger when input-blocker is clicked on.
							; note if this is none, input-blocker is not enabled.
							;
							; if set to 'remove  then the trigger is the default, which
							; simply removes the overlay and disables input-blocker.
							trigger: 'remove
							
						]					
					][
						;-------------------------------------------------------------------
						;-------------------------------------------------------------------
						;-------------------------------------------------------------------
						; window doesn't properly fit popup in display!
						vprint "WINDOW TOO SMALL!"
						
						popup/overlay-scroll-frame: sl/layout/within/options [
								scroll-frame tight [
									sf: column tight [
									]
								]
						] 'column [0.0.0.128 2x2]
						
;						sf: popup/overlay-scroll-frame/collection/1
						vprint "--->"
						vprobe type? sf
						vprint "<---"
						
						;print type? popup/overlay-glob/frame
						;print sf/valve/style-name
						;probe popup/overlay-glob/options
						;popup/overlay-glob/options: copy []
						;frame-lib/von
						sf/valve/gl-collect sf popup/overlay-glob
						;frame-lib/voff
						;print type? popup/overlay-glob/frame
						
						fill* popup/overlay-glob/aspects/offset 0x0
						fill* popup/overlay-glob/material/border-size 0x0
						
						
						sf/valve/gl-fasten sf
;						
						popup/overlay-scroll-frame/valve/gl-fasten popup/overlay-scroll-frame
						
						pop-size/y: min pop-size/y popup/max-size/y
						
						if pop-size/y > win-size/y [
							pop-pos/y: 5
							pop-size/y: win-size/y - 10
						]
						
						pop-size/x: pop-size/x + 25
						
						if (pop-pos/y + pop-size/y) > win-size/y [
							pop-pos/y: win-size/y - pop-size/y
						]
					
						
						if (pop-pos/x + pop-size/x) > win-size/x [
							pop-pos/x: win-size/x - pop-size/x - 5
						]
						
						fill* popup/overlay-scroll-frame/material/position pop-pos
						fill* popup/overlay-scroll-frame/material/dimension pop-size

						event-lib/queue-event make event [
							action: 'add-overlay
							; the glob we want to overlay
							frame: popup/overlay-scroll-frame
							
							; the event to trigger when input-blocker is clicked on.
							; note if this is none, input-blocker is not enabled.
							;
							; if set to 'remove  then the trigger is the default, which
							; simply removes the overlay and disables input-blocker.
							trigger: 'remove
							
						]					
					]
				]
				vout
			]
			
			
			;-----------------
			;-        conceal()
			;
			; signals glass to remove our popup glob from the overlay
			;-----------------
			conceal: func [
				popup
			][
				vin [{glass/popup/conceal()}]
				vout
			]
			
			
			;-----------------
			;-        materialize()
			;-----------------
			materialize: func [
				popup
				/local ovr-mtrl min-size
			][
				vin [{glass/popup/materialize()}]
				; create our overlay instance.
				switch/default type?/word popup/valve/overlay-glob-class [
					; for now, the only supported type.  eventually we will support marble classes directly.
					block! [
						popup/overlay-glob: sl/layout/within/options popup/valve/overlay-glob-class 'column [tight 0.0.255 0.0.255]
						ovr-mtrl: popup/overlay-glob/material
						;min-size: content* ovr-mtrl/dimension
						;ovr-mtrl/material/dimension: max min-size ((min-size * 0x1) + (second content* popup/))
						;link*/reset ovr-mtrl/position popup/material/position
						
						; will be filled by reveal()
						fill* ovr-mtrl/position 0x0
						
						link*/reset ovr-mtrl/dimension ovr-mtrl/min-dimension
					]
					
				][
					vprint ["warning: bad or no default overlay to setup in popup: " popup/valve/style-name]
				]
				vout
			]
			
			
			;-----------------
			;-        popup-handler()
			;
			;-----------------
			popup-handler: func [
				event [object!]
				/local popup
			][
				vin [{HANDLE POPUP}]
				vprint event/action
				popup: event/marble
				
				switch/default event/action [
					start-hover [
						fill* popup/aspects/hover? true
					]
					
					end-hover [
						fill* popup/aspects/hover? false
					]
					
					select [
						fill* popup/aspects/selected? true
						
						; we call do-action BEFORE our handling, cause it might 
						; manipulate the overlay before we use it.
						event/marble/valve/do-action event
						
						popup/valve/reveal popup event
						
						
					]
					
					; successfull click
					release [
						fill* popup/aspects/selected? false
						;do-action event
					]
					
					; canceled mouse release event
					drop no-drop [
						fill* popup/aspects/selected? false
						;do-action event
					]
					
					swipe [
						fill* popup/aspects/hover? true
						;do-action event
					]
				
					drop? [
						fill* popup/aspects/hover? false
						;do-action event
					]
				
					focus [
;						event/marble/label-backup: copy content* event/marble/aspects/label
;						if pair? event/coordinates [
;							set-cursor-from-coordinates event/marble event/coordinates false
;						]
;						fill* event/marble/aspects/focused? true
					]
					
					unfocus [
;						event/marble/label-backup: none
;						fill* event/marble/aspects/focused? false
					]
					
					text-entry [
;						type event
					]
				][
					vprint "IGNORED"
				]
				
				; totally configurable end-user event handling.
				; not all actions are implemented in the actions, but this allows the user to 
				; add his own events AND his own actions and still work within the API.
				event/marble/valve/do-action event
				
				vout
				none
			]
			
						

			;-----------------
			;-        setup-style()
			;-----------------
			; a callback to extend anything in the marble AFTER Glass has finished with its own setup
			;
			; this is used by styles for their own custom data requirements.
			;
			; styles may also provide application setup hooks, but usually do so via extensions to the
			; the specification parser, using dialect()
			; 
			; some styles will also add default stream handlers (like viewports)
			;-----------------
			setup-style: func [
				marble
			][
				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/stylize()}]
				
				event-lib/handle-stream/within 'popup-handler :popup-handler marble
				vout
			]
		]
	]
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %popup.r 
    date: 20-Jun-2010 
    version: 0.1.1 
    slim-name: 'popup 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: POPUP
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: STYLE-DROPLIST  v0.2.3
;--------------------------------------------------------------------------------

append slim/linked-libs 'style-droplist
append/only slim/linked-libs [


;--------
;-   MODULE CODE




;- slim/register/header
slim/register/header [
	; declare words so they stay bound locally to this module

	layout*: get in system/words 'layout
	
	

	;- LIBS
	to-color: none
	
	!glob: none
	glob-lib: slim/open/expose 'glob none [!glob to-color]
	
	marble-lib: slim/open 'marble none
	
	
	!plug: liquify*: content*: fill*: link*: unlink*: none
	liquid-lib: slim/open/expose 'liquid none [
		!plug 
		[liquify* liquify ] 
		[content* content] 
		[fill* fill] 
		[link* link] 
		[unlink* unlink] 
		[dirty* dirty]
	]
	
	
	prim-bevel: prim-x: prim-label: prim-list: prim-glass: prim-item-stack: none
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: none
	top-half: bottom-half: find-same: get-aspect: include: include-different: none
	label-dimension: none
	sillica-lib: slim/open/expose 'sillica none [
		include
		include-different
		get-aspect
		find-same
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		label-dimension
		prim-bevel
		prim-x
		prim-label
		prim-list
		prim-glass
		prim-item-stack
		top-half
		bottom-half
	]
	epoxy-lib: slim/open/expose 'epoxy none [!box-intersection]
	event-lib: slim/open 'event none

	

	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;

	;--------------------------------------------------------
	;-   
	;- !DROPLIST[ ]
	!droplist: make marble-lib/!marble [
	
		;-    Aspects[ ]
		aspects: context [
		
		
			;-        offset:
			offset: -1x-1
			
			;-        focused?:
			focused?: false

			;-        hover?:
			hover?: false
			
			;-        selected?:
			selected?: false
			
			;-        color:
			; color of bg
			color: white * .8
			
			;- 		droplist SPECIFICS
			;-        items:
			items: make-bulk/properties/records 3 [
				label-column: 1
			][
				"New Brunswick123456789" [] 00
				"New York" [] 11
				"Montreal" [] 22 
				"L.A." [] 33
				"L.A." [] 37 ; tests similar labels in the droplist
				"Paris" [] 44
				"London 23iwuety eoitetoiu" [] 55
				"Rome" [] 66
				"Pekin" [] 77
				"Chicago" [] 88
				"Amsterdam" [] 99
				"Monza" [] 1010
				"Mexico City" [] 1111
				"Bangkok" [] 1212
			]
			
			
			
			;-        columns:
			; how many columns in item data?
			;
			; for now this is hard-set to 2, but in future versions, we will expand and allow several label columns.
			;columns: 2
			
			
			;-        leading:
			; vertical spacing between items.
			leading: 8
			
			
			;-        font:
			font: theme-menu-item-font
			
			;-        min-width:
			; minimum width of drop-down.
			;
			; carefull cause dimension & min-width is are indirect observers (don't link this to them)
			min-width: 150x0
			
			
			;-        picked-item:
			; when something on the drop list, is actually picked (selected), we insert the value here.
			;
			; note this is NOT a copy, so don't change it.  copy it if you really need to edit the string.
			;
			; setting picked-item manually doesn't cause ANY reaction internally... nothing is linked to it.
			picked-item: none
			
		]

		
		;-    Material[]
		material: make material [
			;-        fill-weight:
			fill-weight: 1x1
			

			;-        item-count:
			; returns the number of items in droplist (length? items / columns).
			item-count: none
			
			;-        current-item:
			; if an item is under mouse, highlight it
			current-item: none
			
			
			;-        primitive:
			; the drop-list is special in that its primitive actually drives some of the basic
			; dimension property.
			;
			; for this reason, we pre-build the primitive to draw and store a few
			; values which it calculated here.
			;
			; other plugs will then link to one or more primitive values.
			;
			primitive: none
			
			
			;-        labels-analysis:
			labels-analysis: none
			
			
			;-        labels-dimension:
			labels-dimension: none
			
		]
		
		
		;-    actions:
		; user functions to trigger on events.
		actions: context [
			item-picked: func [event][
				;print "droplist action!"
				;print event/picked
				;probe event/chosen
			]
		]
		
		
		;-    controled-by:
		; to what control is this droplist associated.
		;
		; the marble usig a drop list will put a reference to itself here
		controled-by: none
		
		
				
		;-    valve[ ]
		valve: make valve [
		
			;-        style-name:
			; used as a label for debugging and node browsing.
			style-name: 'droplist  
			
			
			;-        drop-primitive[]
			;
			; the primitive is an object defined as:
			;
			; context [
			;     draw-block: [...]
			;     size: 100x100
			; ]
			;
			; the min-dimension will be linked to size via a !select plug
			; 
			drop-primitive: make !plug [
				valve: make valve [
					;-----------------
					;-            process()
					;-----------------
					process: func [
						plug data
						/local blk s item items leading cols font current size line-height hi-box min-width off
					][
						vin [{drop-primitive/process()}]
						; we re-use context
						;probe data
						
						plug/liquid: any [
							plug/liquid 
							;all [vprint "ALLOCATING drop-primitive object" false]
							context [draw-block: copy [] size: 100x100]
						]
						;vprobe data
						;ask "$$$$"
						; make sure interface conforms
						if all [
							;6 >= length? data
							block? items: pick data 1
							;integer? cols: pick data 2
							object? font: pick data 2
							integer? leading: pick data 3
							any [
								string? current: pick data 4
								none? current
							]
							pair? pos: off: pick data 5
						][
							cols: bulk-columns items
							
							; skip bulk header
							items: next items
							
							
							
							;	optional arguments
							min-width: 1x0 * any [pick data 6 0]
							
							line-height: font/size + leading * 0x1
							
							; processed values
							items: extract items cols
							size: min-width
							
							
							; create list box text
							blk: compose [
								fill-pen (black)
								font (font)
							]
							hi-box: none
							foreach item items [
								if same? item current [
									hi-box: pos 
								]
								
								append blk compose [
									text (item) (pos + 4x0 + (leading / 2 * 0x1 - 2)) vectorial
								]
								pos: pos + line-height
								size: max size (1x0 * label-dimension item font)
								size: max size (0x1 * pos)
							]
							
							size: size + 4x2 - (off * 0x1)
							
							; finish highlight, now that we know the actual size of primitive. 
							if hi-box [
								hi-box: compose [(prim-glass hi-box - 2x2  (hi-box + line-height + (1x0 * size) - 2x0) theme-glass-color theme-glass-transparency)]
							]
							blk: append blk hi-box
							plug/liquid/size: size
							plug/liquid/draw-block: blk
						]
						vout
					]
					
					
				]
			]
			

			
			;-        glob-class:
			; defines the glob which will be built by each marble instance.
			;   glob-class/marble  is added automatically by setup.
			glob-class: make !glob [
				pos: none
				
				
				valve: make valve [
					; internal calculation vars
;					p: none
;					d: none
;					e: none
;					h?: none
;					list: none
;					highlight-color: 0.0.0.50
					
					
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup these will be stored within glob/input
						position !pair (random 200x200)
						dimension !pair (100x30)
						color !color  (random white)
						focused? !bool 
						hover? !bool 
						selected? !bool
						
						; list specific
						;items !block ; tag pairs of "label" payload
						;current-item !string
						
						primitive !any
					]
					
					;-            glob/gel-spec:
					; different AGG draw blocks to use, one per layer.
					; these are bound and composed relative to the input being sent to glob at process-time.
					gel-spec: [
						; event backplane
						position dimension 
						[
							line-width 1 
							pen none 
							fill-pen (to-color gel/glob/marble/sid)
							box (data/position=) (data/position= + data/dimension= - 1x1)
						]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						position dimension focused? primitive
						[
							
							; labels
							pen none
							fill-pen black
							line-width 0.5
;							
							
							line-width 0
							pen none
							fill-pen blue
							(
								data/primitive=/draw-block
							)
							
							; for debugging
							;pen 0.0.0.200
							;fill-pen none
							;box (data/position=)  (data/position= + data/dimension= - 1x1)
						]
							
						; controls layer
						;[]
						
						; overlay layer
						; like the bg, it may switched off, so don't depend on it.
						;[]
					]
				]
			]
			
			
			;-----------------
			;-        item-from-coordinates()
			;
			; returns index of item to highlight.
			;-----------------
			item-from-coordinates: func [
				droplist [object!]
				offset [pair!]
				/local i picked font
			][
				vin [{item-from-coordinates()}]
				v?? offset
				font: content* droplist/aspects/font
				; 2x4 is a hard-coded origin where drawing starts
				;v?? coordinates
				picked: offset/y ;second coordinates - 2x4 - content* droplist/material/position
				;v?? picked
				picked: (to-integer (picked / (font/size + content* droplist/aspects/leading)))
				picked: picked + 1 ;+ 2
				;v?? coordinates
				;v?? picked
				vout
				
				picked
			]
			
			
			
			
			
			
			
			;-----------------
			;-        find-item()
			;
			; return the droplist AT the position of supplied item
			;
			; note: when supplying a string it must be the EXACT same string, cause a single list
			;       might have several items with the same label
			;-----------------
			find-item: func [
				droplist [object!]
				item [string! integer!]
				/local items cols
			][
				vin [{find-item()}]
				items: content* droplist/aspects/items
				cols: bulk-columns items
				
				; skip bulk header
				items: next items
				
				;cols: content* droplist/aspects/columns
				bulk-columns items
				unless string? item [
					item: pick items (item - 1 * cols + 1)
				]

				vout				
				; we ignore invalid pick values
				if string? item [
					if item: find-same items item [
						item
					]
				]
			]
			;-----------------
			;-        find-row()
			;
			; return the row at the index of supplied item
			;
			; note: when supplying a string it must be the EXACT same string, cause a single list
			;       might have several items with the same label
			;
			;-----------------
			find-row: func [
				droplist [object!]
				item [string! integer!]
				/local items columns label-column row
			][
				vin [{glass/!} uppercase to-string droplist/valve/style-name {[} droplist/sid {]/find-item()}]
				items: content* droplist/aspects/items
				
				row: either string? item [
				;	item: pick items (item - 1 * columns + 1)
					column: any [
						get-bulk-property items 'label-column
						1
					]
					
					search-bulk-column/same/row items column item
				][
					; if item is larger than row count, none is returned
					get-bulk-row items item
				]

				vout				
				; we ignore invalid pick values
;				if item: find-same items item [
;					item
;				]

				row
			]
			
			
			;-----------------
			;-        choose-item()
			;
			; set the current-item.
			;
			;-----------------
			choose-item: func [
				droplist [object!]
				item [string! none!] "none clears the chosen list"
			][
				vin [{choose-item()}]
				if not same? item content* droplist/material/current-item [
					fill* droplist/material/current-item item
				]
				vout
			]
			
			
			
			
			;-----------------
			;-        droplist-handler()
			;
			; this handler is used for testing purposes only. it is shared amongst all marbles, so its 
			; a good and memory efficient handler.
			;-----------------
			droplist-handler: func [
				event [object!]
				/local list picked i l
			][
				vin [{HANDLE LIST EVENTS}]
				vprint event/action
				droplist: event/marble
				
				switch/default event/action [
					start-hover [
						fill* droplist/aspects/hover? true
					]
					
					
					hover [
						vprint "RESOLVING CHOSEN ITEM"
						if picked: item-from-coordinates droplist event/offset [
							if picked: find-item droplist picked [
								picked: first picked
							]
						]

						choose-item droplist picked
					]

					
					end-hover [
						fill* droplist/aspects/hover? false
						
						choose-item droplist none
						;probe content* droplist/aspects/chosen
						
						;probe content* droplist/material/labels-analysis
					]
					

;                   ; OLDER PICK METHOD
;					select [
;						vprint "RESOLVING CHOSEN ITEM"
;						if picked: item-from-coordinates droplist event/coordinates [
;							if picked: find-item droplist picked [
;								picked: first picked
;								choose-item droplist picked
;							]
;						]
;						
;						event-lib/queue-event make event compose/only [
;							action: 'pick-item
;							picked: (picked)
;						]
;						event-lib/queue-event compose [viewport: event/viewport action: 'remove-overlay]
;					]

					select [
						;vprint "RESOLVING CHOSEN ITEM"
						if picked: item-from-coordinates droplist event/offset [
						;v?? picked
						
							if picked: find-row droplist picked [
								;probe content* droplist/aspects/chosen
								
								event-lib/queue-event make event compose/only [
									action: 'pick-item
									picked: (first picked)
									; we now return the whole row of droplist, since it may contain user data beyond
									; what the droplist requires.
									picked-data: (picked)
								]
								event-lib/queue-event compose [viewport: event/viewport action: 'remove-overlay]
							]
						]
					]




					pick-item [
						; you could generate this event manually if you wish to simulate
						; a drop-list selection, usefull for user-specified shortcuts
						fill* droplist/aspects/picked-item event/picked
					]
										
					; successfull click
					release [
						fill* droplist/aspects/selected? false
						;do-action event
					]
					
					; canceled mouse release event
					drop no-drop [
						fill* droplist/aspects/selected? false
						;do-action event
					]
					
					swipe [
						fill* droplist/aspects/hover? true
						;do-action event
					]
				
					drop? [
						fill* droplist/aspects/hover? false
						;do-action event
					]
					
					
;					scroll focused-scroll [
;						switch event/direction [
;							pull [
;								i: get-aspect event/marble 'list-index
;								l: get-aspect event/marble 'list
;								v: get-aspect/or-material event/marble 'visible-items
;								if (i + v - 1) < (to-integer (0.5 * length? l)) [
;									fill* event/marble/aspects/list-index i + event/amount
;								]
;							]
;							
;							push [
;								i: get-aspect event/marble 'list-index
;								if i > 1 [
;									fill* event/marble/aspects/list-index i - event/amount
;								]
;							]
;						]
;					]
					
					
;					focus [
;						event/marble/label-backup: copy content* event/marble/aspects/label
;						if pair? event/coordinates [
;							set-cursor-from-coordinates event/marble event/coordinates false
;						]
;						fill* event/marble/aspects/focused? true
;					]
					
;					unfocus [
;						event/marble/label-backup: none
;						fill* event/marble/aspects/focused? false
;					]
					
;					text-entry [
;						type event
;					]
				][
					vprint "IGNORED"
				]
				
				; totally configurable end-user event handling.
				; not all actions are implemented in the actions, but this allows the user to 
				; add his own events AND his own actions and still work within the API.

				event/marble/valve/do-action event
				
				vout
				none
			]
			
			
			;-----------------
			;-        materialize()
			; 
			; <TO DO> make a purpose built epoxy plug for visible-items and instantiate it.
			;-----------------
			materialize: func [
				droplist
			][
				vin [{materialize()}]
				
				droplist/material/item-count: liquify* epoxy/!bulk-row-count
				droplist/material/primitive: liquify* drop-primitive
				droplist/material/current-item: liquify* !plug
				
				droplist/material/labels-analysis: liquify* epoxy/!bulk-label-analyser
				droplist/material/labels-dimension: liquify* epoxy/!bulk-label-dimension
				droplist/material/min-dimension: liquify* epoxy/!pair-max
				vout
			]
			

			;-----------------
			;-        fasten()
			;-----------------
			fasten: func [
				droplist
				/local mtrl aspects
			][
				vin [{fasten()}]
				mtrl: droplist/material
				aspects: droplist/aspects
				
				; setup item count
				link* mtrl/item-count aspects/items
				;link* mtrl/item-count aspects/columns
				
				; build primitive automatically when its states change
				link* mtrl/primitive aspects/items
				;link* mtrl/primitive aspects/columns
				link* mtrl/primitive aspects/font
				link* mtrl/primitive aspects/leading
				link* mtrl/primitive mtrl/current-item
				link* mtrl/primitive mtrl/position
				link* mtrl/primitive aspects/min-width
				

				; pre-process label data
				link* mtrl/labels-analysis aspects/items
				link* mtrl/labels-analysis aspects/font
				link* mtrl/labels-analysis aspects/leading
				link* mtrl/labels-analysis mtrl/position
				
				; calculate min-size based on label data measurements.
				link* mtrl/labels-dimension mtrl/labels-analysis
				
				link*/reset mtrl/min-dimension mtrl/labels-dimension
				link* mtrl/min-dimension aspects/min-width
				
				vout
			]
;			
;			
;			;-----------------
;			;-        specify()
;			;-----------------
;			specify: func [
;				droplist [object!]
;				spec [block!]
;				stylesheet [block!] "Required so stylesheet propagates in marbles we create"
;				/local data pair-count tuple-count
;			][
;				vin [{glass/!} uppercase to-string droplist/valve/style-name {[} droplist/sid {]/specify()}]
;				
;				; polymorphism!
;				droplist: marble-lib/!marble/valve/specify droplist spec stylesheet
;				
;				; do our own stuff
;				; we allocate the scroller here, since we have a pointer to the stylesheet.
;			;	list/scroller: alloc-marble/using 'scroller [] stylesheet
;			;	list/scroller/orientation: 'vertical
;				
;				vout
;				droplist
;			]
			
			
			

			;-----------------
			;-        setup-style()
			;-----------------
			; a callback to extend anything in the marble AFTER Glass has finished with its own setup
			;
			; this is used by styles for their own custom data requirements.
			;
			; styles may also provide application setup hooks, but usually do so via extensions to the
			; the specification parser, using dialect()
			; 
			; some styles will also add default stream handlers (like viewports)
			;-----------------
			setup-style: func [
				droplist
			][
				vin [{glass/!} uppercase to-string droplist/valve/style-name {[} droplist/sid {]/stylize()}]
				
				; just a quick stream handler for our droplist
				event-lib/handle-stream/within 'droplist-handler :droplist-handler droplist
				
				
				vout
			]
		]
	]
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %style-droplist.r 
    date: 17-May-2010 
    version: 0.2.3 
    slim-name: 'style-droplist 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: STYLE-DROPLIST
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: REQUESTOR  v0.1.0
;--------------------------------------------------------------------------------

append slim/linked-libs 'requestor
append/only slim/linked-libs [


;--------
;-   MODULE CODE


;- slim/register/header
slim/register/header [

	; declare words so they stay bound locally to this module
	!plug: liquify*: !glob: content*: fill*: link*: unlink*: detach*: none
	
	; sillica lib
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: none
	prim-bevel: prim-x: prim-label: none
	include: none

	layout*: get in system/words 'layout
	
	

	;- LIBS
	glob-lib: slim/open/expose 'glob none [!glob]
	liquid-lib: slim/open/expose 'liquid none [
		!plug 
		[liquify* liquify ] 
		[content* content] 
		[fill* fill] 
		[link* link] 
		[unlink* unlink] 
		[detach* detach] 
	]
	sillica-lib: slim/open/expose 'sillica none [
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		prim-bevel
		prim-x
		prim-label
		include
	]
	epoxy-lib: slim/open/expose 'epoxy none [!box-intersection]

	
	group-lib: slim/open 'group none
	

	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;

	
	
	;--------------------------------------------------------
	;-   
	;- !REQUESTOR[ ]
	!requestor: make group-lib/!group [
	
		;-    aspects[ ]
		aspects: make aspects [
			color: none ; white * 0.3
		]
		
		
		;-    material[ ]
		material: make material [
			border-size: 0x0
		]


		;-    viewport:
		; we use this to track on which viewport this requestor is currently displayed.
		; if none, we aren't currently visible.
		;
		; the viewport is stored so requestor can be removed autonomously later.
		viewport: none
		
	
		
		;-    content-specification:
		; this stores the spec block we execute on setup.
		;
		; it is handled normally by frame.
		;
		; note that the dialect for the group itself, is completely redefined for each group.
		content-specification: [
			title-bar [
				title-bar: requestor-title left "Request"
			]
			column []
		]
		
		;-    title-label:
		title-bar: none
		
		
		
		;-    layout-method:
		layout-method: 'column
		
		
		
		;-    valve []
		valve: make valve [

			type: '!marble


			;-        style-name:
			style-name: 'requestor
		

			;-        bg-glob-class:
			;-        fg-glob-class:
			fg-glob-class: none
			bg-glob-class: make glob-lib/!glob [
				valve: make valve [
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup  these will be stored within the instance under input
						position !pair 
						dimension !pair
						color !color (blue)
						frame-color  !color 
						;clip-region !block ([0x0 1000x1000])
						;parent-clip-region !block ([0x0 1000x1000])
					]
					
					;-            glob/gel-spec:
					gel-spec: [
						; event backplane
						none
						[]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						 position dimension color frame-color ;clip-region parent-clip-region
						[
							(sillica-lib/prim-shadow-box data/position= data/dimension=  5 )
							
							line-width 0
							fill-pen theme-requestor-bg-color
							pen (theme-knob-border-color)
							box (data/position=) (data/position= + data/dimension= - 1x1) 
							
							;(sillica-lib/prim-bevel data/position= data/dimension=  any [data/color= theme-bevel-color] 0.5 1)
						]
						
						; controls layer
						;[]
						
					]
				]
			]

			
	
			;-----------------
			;-        group-specify()
			;-----------------
			group-specify: func [
				group [object!]
				spec [block!]
				stylesheet [block! none!] "required so stylesheet propagates in marbles we create"
				/local data column
			][
				vin [{glass/!} uppercase to-string group/valve/style-name {[} group/sid {]/group-specify()}]
				column: group/collection/2
				
				parse spec [
					any [
						set data string! (
							fill* group/title-bar/aspects/label data ;group/collection/1/aspects/label data
						) |
						set data tuple! (
							set-aspect group 'color data
						) |
						set data pair! (
							fill* group/materials/min-dimension data
						) | 
						set data block! (
							column/valve/specify column reduce [data] stylesheet
							column/valve/gl-fasten column
						) |

						skip (vprint "->")
					]
				]

				vout
				group
			]
		]
	]
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %requestor.r 
    date: 27-May-2010 
    version: 0.1.0 
    slim-name: 'requestor 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: REQUESTOR
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: GROUP  v1.0.0
;--------------------------------------------------------------------------------

append slim/linked-libs 'group
append/only slim/linked-libs [


;--------
;-   MODULE CODE




;- slim/register/header
slim/register/header [

	; declare words so they stay bound locally to this module
	!plug: liquify*: !glob: content*: fill*: link*: unlink*: detach*: none
	
	; sillica lib
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: none
	prim-bevel: prim-x: prim-label: none
	include: none

	layout*: get in system/words 'layout
	
	

	;- LIBS
	glob-lib: slim/open/expose 'glob none [!glob]
	liquid-lib: slim/open/expose 'liquid none [
		!plug 
		[liquify* liquify ] 
		[content* content] 
		[fill* fill] 
		[link* link] 
		[unlink* unlink] 
		[detach* detach] 
	]
	sillica-lib: slim/open/expose 'sillica none [
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		prim-bevel
		prim-x
		prim-label
		include
	]
	epoxy-lib: slim/open/expose 'epoxy none [!box-intersection]

	
	frame-lib: slim/open 'frame none
	

	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;

	
	
	;--------------------------------------------------------
	;-   
	;- !GROUP[ ]
	!group: make frame-lib/!frame [
	
		;-    aspects[ ]
		aspects: make aspects []
		
		
		;-    material[ ]
		material: make material [border-size: 0x0]

		;-    spacing-on-collect:
		; when collecting marbles, automatically set their offset to this value
		; in groups, usually you want content to be juxtaposed.
		spacing-on-collect: 5x5
		
		
		
		;-    layout-method:
		; most groups are horizontal
		layout-method: 'row
		
		
		
		;-    content-specification:
		; this stores the spec block we execute on setup.
		;
		; it is handled normally by frame.
		;
		; note that the dialect for the group itself, is completely redefined for each group.
		;
		; also, if you wish to assign the marbles to words, do not use set-word notation in
		; the specification (its disabled), but assign them later in something like materialize() or stylize()
		; using the group/collection to retrieve them.
		content-specification: none
		
		
		;-    specified?:
		; when specify is called the first time, this is set to true.  succeding calls to specify, will
		; ignore content-specification allocation and go directly to group-specify
		;
		; this prevents the group from re-allocating the content-specification all over again!
		specified?: false
		
		
		
		;-    valve []
		valve: make valve [

			type: '!marble


			;-        style-name:
			style-name: 'group
		

			;-        bg-glob-class:
			;-        fg-glob-class:
			; no need for any globs.  just sizing fastening and automated liquification of grouped marbles.
			bg-glob-class: none
			fg-glob-class: none

		
			;-----------------
			;-        specify()
			;
			; parse a specification block during initial layout operation
			;
			; groups automatically create new marble instances at specify() time.
			;
			; they are also responsible for calling layout setup operations providing any
			; environment which is required by new marbles
			;
			; the group will look at the specification and provide a single interface
			; to all its marbles.  it can generate the marbles before, or after the spec
			; is managed, its really up to it.
			;
			; this default specify function pre-allocates our content-specification
			; and calls the new group-specify() method.
			;-----------------
			specify: func [
				group [object!]
				spec [block!]
				stylesheet [block! none!] "required so stylesheet propagates in marbles we create"
				/wrapper "this is a wrapper, gl-fasten() will react accordingly"
				/local marble item pane data marbles set-word do-blk
			][
				vin [{glass/!} uppercase to-string group/valve/style-name {[} group/sid {]/specify()}]
			;	v?? spec
				
				stylesheet: any [stylesheet master-stylesheet]
				
				
				unless group/specified? [
					group/specified?: true
					if wrapper [
						include group/options 'wrapper
					]
	
					; PRE-ALLOCATE CONTENT
					pane: regroup-specification group/content-specification 
					new-line/all pane true
					vprint "skipping inner pane attributes"
					pane: find pane block!
					v?? pane
					
					; create & specify inner marbles
					foreach item pane [
						;---
						; set words are disabled (ignored)
						if set-word? set-word: pick item 1 [
	;						; store the word to set, then skip it.
	;						; after we use set on the returned marble.
	;						print "SET WORD!"
	;						
							item: next item
						]
						
						either marble: alloc-marble/using first item next item stylesheet [
							marbles: any [marbles copy []]
							
							append marbles marble
							
							marble/frame: group
							
							marble/valve/gl-fasten marble

							if set-word? :set-word [
								set :set-word marble
							]
							
						][
							; because of specification's parsing, this code should never really be reached
							vprint ["ERROR creating new marble of type: " item " in group!"]
						]
					]
					
					; add all children to our collection
					group/valve/accumulate group marbles
				]
				
				;ask "1"
				group: group/valve/group-specify group spec stylesheet	
				
				
				;ask "2"
				;probe type? group/frame
				
				; take this group and fasten it.
				group/valve/gl-fasten group
				
				;ask "3"
				
				;------
				; cleanup GC
				marbles: spec: stylesheet: marble: pane: item: data: none
				vout/with [ uppercase to-string group/valve/style-name {[} group/sid {]/specify()}]
				
				group
			]

	
			;-----------------
			;-        group-specify()
			;-----------------
			group-specify: func [
				group [object!]
				spec [block!]
				stylesheet [block! none!] "required so stylesheet propagates in marbles we create"
				/local data
			][
				vin [{glass/!} uppercase to-string group/valve/style-name {[} group/sid {]/group-specify()}]
				parse spec [
					any [
						set data tuple! (
							vprint "group background COLOR!" 
							set-aspect group 'color data
						) |
						set data pair! (
							vprint "group BORDER SIZE!" 
							fill* group/material/border-size data
						) |

						skip (vprint "->")
					]
				]
				vout
				group
			]
		]
	]
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %group.r 
    date: 20-Jun-2010 
    version: 1.0.0 
    slim-name: 'group 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: GROUP
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: STYLE-PROGRESS  v0.8.0
;--------------------------------------------------------------------------------

append slim/linked-libs 'style-progress
append/only slim/linked-libs [


;--------
;-   MODULE CODE




;- slim/register/header
slim/register/header [
	; declare words so they stay bound locally to this module

	layout*: get in system/words 'layout
	
	

	;- LIBS
	to-color: none
	
	!glob: none
	glob-lib: slim/open/expose 'glob none [!glob to-color]
	
	marble-lib: slim/open 'marble none
	
	
	!plug: liquify*: content*: fill*: link*: unlink*: none
	liquid-lib: slim/open/expose 'liquid none [
		!plug 
		[liquify* liquify ] 
		[content* content] 
		[fill* fill] 
		[link* link] 
		[unlink* unlink] 
		[dirty* dirty]
	]
	
	
	prim-bevel: prim-x: prim-label: prim-knob: prim-recess: prim-glass: none
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: none
	top-half: bottom-half: sub-box: none
	sillica-lib: slim/open/expose 'sillica none [
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		prim-bevel
		prim-x
		prim-label
		prim-knob
		prim-recess
		prim-cavity
		prim-glass
		top-half
		bottom-half
		sub-box
	]
	epoxy-lib: slim/open/expose 'epoxy none [!box-intersection]

	

	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;

	;--------------------------------------------------------
	;-   
	;- !PROGRESS[ ]
	!progress: make marble-lib/!marble [
	

		;-    Aspects[ ]
		aspects: make aspects [
			
			;-        color:
			color: none


			;-        bg-color:
			bg-color: theme-progress-bg-color
			
			
			;-        minimum:
			minimum: 1
			
			
			;-        maximum:
			maximum: 10
			
			
			;-        progress:
			progress: 5


		]

		
		;-    Material[]
		material: make material [
			
			;-        orientation:
			; in what orientation will the progress work. 'vertical 'horizontal 'auto
			; if its set to 'auto, fasten() will set this depending on parent frame orientation.
			orientation: 'auto
			
			
			;-        min-dimension
			min-dimension: 20x20
		]
		
		
		
		
			
		
		;-    valve[ ]
		valve: make valve [
			;-        style-name:
			; used as a label for debugging and node browsing.
			style-name: 'progress  
			
			
			
			
			;-        glob-class:
			; defines the glob which will be built by each marble instance.
			;   glob-class/marble  is added automatically by setup.
			glob-class: make !glob [
				end: none
				
				valve: make valve [
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup these will be stored within glob/input
						position !pair (random 200x200)
						dimension !pair (100x30)
						color !color  (random white)
						bg-color !color
						minimum !integer
						maximum !integer
						progress !integer
						orientation !word
					]
					
					;-            glob/gel-spec:
					; different AGG draw blocks to use, one per layer.
					; these are bound and composed relative to the input being sent to glob at process-time.
					gel-spec: [
						; event backplane
						none ;position dimension 
						[
;							line-width 1 
;							pen none 
;							fill-pen (to-color gel/glob/marble/sid) 
;							box (data/position=) (data/position= + data/dimension= - 1x1)
						]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						position dimension minimum maximum progress color bg-color orientation
						[
							
							; BG
							(
								prim-recess 
									data/position= 
									data/dimension= - 1x1
									data/bg-color=
									theme-border-color
									data/orientation=
							)
;							(
;								prim-cavity/all/colors
;									data/position= 
;									data/dimension= - 1x1
;									none
;									theme-border-color
;							)
							
							
							; BAR
							fill-pen white
							pen none
							(
								end: data/position= + sub-box/orientation data/dimension= - 2x2 data/minimum= data/maximum= data/progress= data/orientation=
								[]
							)
							;box 2 (data/position= + 1x1) (end)
							(prim-glass/corners data/position= + 1x1  end  theme-glass-color  theme-glass-transparency  2)
;							
;
;from "box start" [pair!]
;		to "box end"  [pair!]
;		color [tuple!]
;		transparency [integer!] "0-255"
;		/corners corner
;
;(
;								prim-knob/grit 
;									data/position= + 2x2
;									sub-box/orientation data/dimension= - 5x5 data/minimum= data/maximum= data/progress= data/orientation=
;									none
;									none ;theme-knob-border-color * 0.5
;									data/orientation=
;									3
;									3
;							)
							
							
							
						]
							
						; controls layer
						;[]
						
						; overlay layer
						; like the bg, it may switched off, so don't depend on it.
						;[]
					]
				]
			]
			
			
			
			
			;-----------------
			;-        setup-style()
			;-----------------
			; a callback to extend anything in the marble AFTER Glass has finished with its own setup
			;
			; this is used by styles for their own custom data requirements.
			;
			; styles may also provide application setup hooks, but usually do so via extensions to the
			; the specification parser, using dialect()
			; 
			; some styles will also add default stream handlers (like viewports)
			;-----------------
			setup-style: func [
				scroller
			][
				vin [{glass/!} uppercase to-string scroller/valve/style-name {[} scroller/sid {]/setup-style()}]
				
				; just a quick stream handler for all scrollers
				;event-lib/handle-stream/within 'scroller-handler :scroller-handler scroller
				vout
			]
			
			
			;-----------------
			;-        materialize()
			;-----------------
			materialize: func [
				scroller
			][
				vin [{glass/!} uppercase to-string scroller/valve/style-name {[} scroller/sid {]/materialize()}]
				scroller/material/orientation: liquify*/fill !plug scroller/material/orientation

				vout
			]
			
			
			
			;-----------------
			;-        fasten()
			;-----------------
			fasten: func [
				scroller
				/local value mtrl aspects vertical? 
			][
				vin [{glass/!} uppercase to-string scroller/valve/style-name {[} scroller/sid {]/fasten()}]
				mtrl: scroller/material
				aspects: scroller/aspects
				
				;-----------
				; specify orientation based on frame, if its not explictely set.
				; note that because the orientation depends on fastening and that this isn't
				; a liquified process, the layout method is an attribute of the frame directly.
				if 'auto = content* mtrl/orientation [
					if in scroller/frame 'layout-method [
						if scroller/frame/layout-method = 'column [
							fill* mtrl/orientation 'horizontal
							vertical?: false
						]
						if scroller/frame/layout-method = 'row [
							fill* mtrl/orientation 'vertical
							vertical?: true
						]
					]
				]
				
				; if orientation was set to 'auto
				if logic? vertical? [
					fill* mtrl/fill-weight either vertical? [0x1][1x0]
				]
					
				
				;probe content value
				
				;ask "---"
				
				;pipe-server
				vout
			]
			
			
			
			
		]
	]
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %style-progress.r 
    date: 27-May-2010 
    version: 0.8.0 
    slim-name: 'style-progress 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: STYLE-PROGRESS
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: GROUP-SCROLLED-LIST  v1.0.0
;--------------------------------------------------------------------------------

append slim/linked-libs 'group-scrolled-list
append/only slim/linked-libs [


;--------
;-   MODULE CODE





;- slim/register/header
slim/register/header [

	; declare words so they stay bound locally to this module
	!plug: liquify*: !glob: content*: fill*: link*: unlink*: detach*: none
	
	; sillica lib
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: none
	prim-bevel: prim-x: prim-label: none
	include: none

	layout*: get in system/words 'layout
	
	

	;- LIBS
	glob-lib: slim/open/expose 'glob none [!glob]
	liquid-lib: slim/open/expose 'liquid none [
		!plug 
		[liquify* liquify ] 
		[content* content] 
		[fill* fill] 
		[link* link] 
		[unlink* unlink] 
		[detach* detach] 
		[attach* attach]
	]
	sl: slim/open/expose 'sillica none [
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		prim-bevel
		prim-x
		prim-label
		include
	]
	epoxy-lib: slim/open/expose 'epoxy none [!box-intersection]

	
	group-lib: slim/open 'group none
	
	bulk: slim/open 'bulk none
	

	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;

	
	
	;--------------------------------------------------------
	;-   
	;- !SCROLLED-LIST[ ]
	!scrolled-list: make group-lib/!group [
	
		;-    aspects[ ]
		aspects: make aspects [
			;-        items:
			; this uses the newer convention used in choice & droplist.
			; is a direct reference to the list's aspects/list plug.
			items: none
			
			;-        label:
			label: none
			
			;-        filter:
			filter: none
			
		]
		
		
		;-    material[ ]
		material: make material [
			border-size: 0x0

			;-        filtered-items:
			; this is provided as utility since you might want to use the filtered list elsewhere.
			;
			; you may only LINK TO since its allocated and linked internally by the group.
			filtered-items: none
			
			;-        user-min-dimension:
			user-min-dimension: none
			
		]


		;-    list-marble:
		list-marble: none
		
		;-    scroller-marble:
		scroller-marble: none
		
		;-    field-marble:
		field-marble: none
		
		;-    label-marble:
		label-marble: none
		
		;-    options-pane:
		options-pane: none
		
		;-    filter-pane:
		filter-pane: none
		
		;-    stiffness:
		stiffness: none
		
		
		
		;-    content-specification:
		; this stores the spec block we execute on setup.
		;
		; it is handled normally by a row frame.
		;
		; note that the dialect for the group itself, is completely redefined for each group.
		;
		; remember that the group itself is a frame, so you can set its looks, and layout mode normally.
		content-specification: [
			label-marble: label "LABEL"
			row tight [
				list-marble: list
				column tight [
					options-pane: column tight []
					;choice stiff 20x25 "V"
					scroller-marble: scroller stretch 0x1 with [fill* material/orientation 'vertical]
				]
			]
			filter-pane: row tight [
				field-marble: field ""
				thin-button stiff 20x25 "*" [fill* field-marble/aspects/label copy ""]
			]
			;choice "BB"
		]
		
		
		spacing-on-collect: 0x0
		
		;-    layout-method:
		layout-method: 'column
		
		
		;-    valve []
		valve: make valve [

			;-        style-name:
			style-name: 'scrolled-list
		

			;-        bg-glob-class:
			;-        fg-glob-class:
			; no need for any globs.  just sizing fastening and automated liquification of grouped marbles.
			bg-glob-class: none
			fg-glob-class: none


			;-----------------
			;-        setup-style()
			;-----------------
			setup-style: func [
				group
			][
				vin [{!scrolled-list/setup-style()}]
				group/material/filtered-items: liquify* epoxy-lib/!bulk-filter
				group/material/user-min-dimension: liquify* !plug
				vout
			]
			
			
			
			
	
			;-----------------
			;-        group-specify()
			;-----------------
			group-specify: func [
				group [object!]
				spec [block!]
				stylesheet [block! none!] "required so stylesheet propagates in marbles we create"
				/local data block-count blk
			][
				vin [{!scrolled-list/group-specify()}]
				block-count: 0
				parse spec [
					any [
						set data tuple! (
							vprint "frame COLOR!" 
							set-aspect group 'color data
						)
						| '.commands set data block! (
							vprint "================================"
							vprobe type? group/options-pane
							blk: bind/copy data group
							sl/layout/within blk group/options-pane
							vprint length? group/options-pane/collection
						)
						| copy data ['with block!] (
							;print "SPECIFIED A WITH BLOCK"
							;frame: make frame data/2
							;liquid-lib/reindex-plug frame
							
							do bind/copy data/2 group 
							
							
							;probe marble/actions
							;ask ""
						)
						
						| 'stiff (
							group/stiffness: 'xy
							;fill* group/material/fill-weight 0x0

						)
						| 'stiff-x (
							group/stiffness: 'x
							;fill* group/material/fill-weight 0x0

						)
						| 'stiff-y (
							group/stiffness: 'y
							;fill* group/material/fill-weight 0x0

						)
						
						; remove the label from this group, we don't need it
						| 'no-label (
							;probe "Will remove label"
							;probe type? group/label-marble
							group/valve/gl-discard group group/label-marble
							;group/valve/gl-fasten group
							
							;halt
						)
						
						; set list data or pick action
						| set data block! (
							;print "!!!!"
							;probe first group/list-marble/valve
							;print "----"
							;fill* group/aspects/items make-bulk/records/properties 3 data [ label-column: 1]
							;group/list-marble/valve/specify group/list-marble reduce [data] stylesheet
							
							
							block-count: block-count + 1
							switch block-count [
								1 [
									; lists support 3 columns, one being label, another options and the last being data.
									; options will change how the item is displayed (bold, strikethru, color, etc).
									fill* group/aspects/items make-bulk/records/properties 3 data [ label-column: 1]
								]
								2 [
									if object? get in group 'actions [
										group/list-marble/actions: make group/list-marble/actions [
											list-picked: make function! [event] bind/copy data group
										]
									]
								]
							]
							
						)
						| set data pair! (
							fill* group/material/user-min-dimension data
						) |

						skip 
					]
				]
				vout
				group
			]
			
			
			
			;-----------------
			;-        fasten()
			;-----------------
			fasten: func [
				group
			][
				vin [{!scrolled-list/fasten()}]
				
				;print type? group/field-marble
				;print type? group/scroller-marble
				;print type? group/list-marble
				;print type? group/label-marble
				
				; reference inner marble data in outer-group
				group/aspects/filter: group/field-marble/aspects/label
				if group/label-marble [
					group/aspects/label: group/label-marble/aspects/label
				]
				;group/aspects/items: group/list-marble/aspects/list ; this isn't used directly by list-marble.
				
				; link up the filter so we can use the filtered-list within the list
				link*/reset group/material/filtered-items group/aspects/items
				link* group/material/filtered-items group/aspects/filter
				
				vprobe content* group/aspects/items
				
				link*/reset group/list-marble/aspects/list group/material/filtered-items
			
				; link-up scroller with list-marble
				link*/reset group/scroller-marble/aspects/visible group/list-marble/material/visible-items
				fill* group/scroller-marble/aspects/minimum 1
				link*/reset group/scroller-marble/aspects/maximum group/list-marble/material/row-count
				
				; this is a more complex link since the scroller contains a bridge, we must connect using a channel.
				attach*/to group/list-marble/aspects/list-index group/scroller-marble/aspects/value 'value
			
				switch group/stiffness [
					xy [
						fill* group/material/fill-weight 0x0
						link*/reset group/material/min-dimension group/material/user-min-dimension
					]
					x [
						fill* group/material/fill-weight 0x1
						link*/reset group/material/min-dimension group/material/user-min-dimension
					]
					xy [
						fill* group/material/fill-weight 1x0
						link*/reset group/material/min-dimension group/material/user-min-dimension
					]
				]
				vout
			]
		]
	]
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %group-scrolled-list.r 
    date: 26-Jun-2010 
    version: 1.0.0 
    slim-name: 'group-scrolled-list 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: GROUP-SCROLLED-LIST
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: SCROLL-FRAME  v1.0.0
;--------------------------------------------------------------------------------

append slim/linked-libs 'scroll-frame
append/only slim/linked-libs [


;--------
;-   MODULE CODE




;- slim/register/header
slim/register/header [

	; declare words so they stay bound locally to this module
	!plug: liquify*: !glob: content*: fill*: link*: unlink*: detach*: none
	
	; sillica lib
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: none
	prim-bevel: prim-x: prim-label: none
	include: none

	layout*: get in system/words 'layout
	
	

	;- LIBS
	glob-lib: slim/open/expose 'glob none [!glob]
	liquid-lib: slim/open/expose 'liquid none [
		!plug 
		[liquify* liquify ] 
		[content* content] 
		[fill* fill] 
		[link* link] 
		[unlink* unlink] 
		[detach* detach]
		[process* process]
	]
	sillica-lib: slim/open/expose 'sillica none [
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		prim-bevel
		prim-x
		prim-label
		include
	]
	epoxy-lib: slim/open/expose 'epoxy none [!box-intersection]

	
	frame-lib: slim/open 'frame none
	group-lib: slim/open 'group none
	

	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;

	
	
	;--------------------------------------------------------
	;-   
	;- !SCROLL-FRAME[ ]
	!scroll-frame: make group-lib/!group [
		;-    aspects[ ]
		aspects: make aspects [
		
			;-        scroller-sizes:
			scroller-sizes: 20x20
			
		]
		
		
		;-    material[ ]
		material: make material [
		
			;-        v-offset:
			v-offset: none
			
			
			;-        h-offset:
			h-offset: none
			
			
			;-        min-dimension:
			min-dimension: 100x100
			
			
			;-        fill-weight:
			; fill up / compress extra space in either direction (independent), but don't initiate resising
			;
			; frames inherit & accumulate these values, marbles supply them.
			fill-weight: 1x1
			
			
			;-        border-size:
			border-size: 0x0
			
			
			; <TO DO> turn this into a bridge so we can set via scrollers or directly using a pair, here.
			;-        inner-offset:
			inner-offset: 0x0
			
			;-        v-max:
			v-max: none
			
			;-        v-visible:
			v-visible: none
			
			;-        h-max:
			h-max: none
			
			;-        h-visible:
			h-visible: none
			
			
		]

		;-    spacing-on-collect:
		; when collecting marbles, automatically set their offset to this value
		; in groups, usually you want content to be juxtaposed.
		spacing-on-collect: 0x0
		
		
		
		;-    layout-method:
		; most groups are horizontal
		layout-method: 'column
		
		
		;-    inner-frame:
		inner-frame: none
		
		;-    v-scroller:
		v-scroller: none
		
		;-    h-scroller:
		h-scroller: none
		
		;-    temp-label:
		;temp-label: none
		
		
		;-    content-specification:
		content-specification: [
			inner-frame: pane
			
			v-scroller: scroller with [fill* material/orientation 'vertical]
			
			h-scroller: scroller with [fill* material/orientation 'horizontal]
			
			;temp-label: title "RR"
		]
		
		
		
		;-    valve []
		valve: make valve [

			type: '!marble


			;-        style-name:
			style-name: 'scroll-frame
		

			;-        bg-glob-class:
			; no need for any globs.  just sizing fastening and automated liquification of grouped marbles.
			bg-glob-class: none


			;-        fg-glob-class:
			; class used to allocate and link a glob drawn IN FRONT OF the marble collection
			;
			; windows use this to create an input blocker, for example.
			-fg-glob-class: make !glob [
				valve: make valve [
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup  these will be stored within the instance under input
						position !pair (random 200x200)
						dimension !pair (300x300)
						disable? !bool
						;color !color
						;frame-color  !color (random white)
						;clip-region !block ([0x0 1000x1000])
						;parent-clip-region !block ([0x0 1000x1000])
					]
					
					;-            glob/gel-spec:
					gel-spec: [
						; event backplane
						disable? position dimension
						[
;							(either data/disable?= [
;								compose [
;									pen none
;									fill-pen (white) ; erases backplane.
;									box  (data/position=) (data/position= + data/dimension= - 1x1)
;								]
;								][[]]
;							)
						]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						; position dimension color frame-color clip-region parent-clip-region
						disable? position dimension
						[
							; here we restore our parent's clip region  :-)
							;clip (data/parent-clip-region=)
							
;							(
;								either data/disable?= [
;									compose [
;										pen none
;										fill-pen (theme-bg-color + 0.0.0.100)
;										box  (data/position=) (data/position= + data/dimension= - 1x1)
;									]
;								][
;									[]
;								]
;							)
;							
							;pen red
							line-width 2
							;line-pattern 10 10
							;
							fill-pen none
							box (data/position=) (data/position= + data/dimension=)
							;(prim-bevel data/position= data/dimension=  white * .75 0.2 3)
							;(prim-X data/position= data/dimension=  (data/color= * 1.1) 10)
			
						]
						
						; controls layer
						;[]
						
						
						; overlay 
						;[]
					]
				]
			]


			
			

			;-----------------
			;-        group-specify()
			;-----------------
			group-specify: func [
				group [object!]
				spec [block!]
				stylesheet [block! none!] "required so stylesheet propagates in marbles we create"
				/local data
			][
				vin [{glass/!} uppercase to-string group/valve/style-name {[} group/sid {]/group-specify()}]
				parse spec [
					any [
						here:
						set data tuple! (
							vprint "group background COLOR!" 
							set-aspect group 'color data
						) |
						set data pair! (
							vprint "group BORDER SIZE!" 
							fill* group/material/border-size data
						) |
						set data block! (
							vprint "setting PANE CONTENT"
							vprobe data
							gl/layout/within/using (bind/copy data group) group/inner-frame stylesheet
						)
						|
						skip (vprint "->")
					]
				]
				vout
				group
			]
			



			
			;-----------------
			;-        gl-materialize()
			;
			; see !marble for details
			;-----------------
;			gl-materialize: func [
;				frame [object!]
;			][
;				vin [{glass/!} uppercase to-string frame/valve/style-name {[} frame/sid {]/gl-materialize()}]
;				; manage relative positioning
;				;if relative-marble? frame [
;					frame/material/position: liquify*/fill epoxy-lib/!junction frame/material/position
;					;link* frame/material/position frame/aspects/offset
;				;]
;
;				frame/material/origin: liquify*/fill !plug frame/material/origin
;				frame/material/dimension: liquify*/fill !dim-plug frame/material/dimension
;				frame/material/content-dimension: liquify*/fill !plug frame/material/content-dimension
;				frame/material/min-dimension: liquify*/fill !plug frame/material/min-dimension
;				frame/material/content-min-dimension: liquify*/fill !plug frame/material/content-min-dimension
;				
;				
;				; manage resizing
;				frame/material/fill-weight: liquify*/fill !plug frame/material/fill-weight
;				frame/material/fill-accumulation: liquify*/fill !plug frame/material/fill-accumulation
;				frame/material/stretch: liquify*/fill !plug frame/material/stretch
;				frame/material/content-spacing: liquify*/fill !plug 0x0
;				frame/material/border-size: liquify*/fill !plug frame/material/border-size
;				
;				; this controls where our PARENT can draw we link to it, cause we restore it after our marbles 
;				; have done their stuff.   We also need it to resolve our own clip-region
;				; 
;				; clip regions are stored as a block containing two pairs
;				;marble/parent-clip-region: liquify* !plug
;				
;				
;				; this controls where WE can draw
;				frame/material/clip-region: liquify* epoxy-lib/!box-intersection
;				;link* frame/material/clip-region frame/material/position
;				;link* frame/material/clip-region frame/material/dimension
;				
;				frame/material/parent-clip-region: liquify* !plug 
;				
;				; our link itself after.
;				;marble/material/origin: liquify*/link epoxy/!fast-add marble/material/position
;				
;
;
;				
;				; this is meant for styles to setup their specific materials.
;				;marble/valve/setup-materials marble
;				
;				vout
;			]
			
			
			;-        !dim-plug:
			!dim-plug: process* 'dim-plug [][
				vin "DIM-plug()"
				vprint "======================================="
				vprint data
				vout
				plug/liquid: any [pick data 1 200x200]
			]
			
	

			;-----------------
			;-        !place-at-edge: []
			;
			; this is a purpose-built positioner for scrollers
			;
			; inputs:
			;    frame-position
			;    frame-dimension
			;    edge
			;    marble-min-size: based on edge, we will use x or y value.
			;-----------------
			!place-at-edge: process* '!place-at-edge [
				position dimension edge min-size
			][
				;vin [{!place-at-edge/process}]
				
				position: pick data 1
			    dimension: pick data 2
			    edge: pick data 3
			    min-size: 1x1 * pick data 4 ; can be a width
			    
		    
			    
			    plug/liquid: switch/default edge [
			    	; synonym for bottom
			    	horizontal [
			    		position + ( dimension - min-size * 0x1) ;- 0x1
			    	]
			    	; synonym for right
			    	vertical [
			    		position + ( dimension - min-size * 1x0) ;- 1x0
			    	]
			    ][0x0]
				
				;vout
			]
			
			;-----------------
			;-        !dimension-at-edge: []
			;
			; this is a purpose-built positioner for scrollers
			;
			; inputs:
			;    frame-position
			;    frame-dimension
			;    edge
			;    marble-min-size: based on edge, we will use x or y value.
			;-----------------
			!dimension-at-edge: process* '!dimension-at-edge [
				position dimension edge min-size
			][
				;vin [{!dimension-at-edge/process}]
				
				position: pick data 1
			    dimension: pick data 2
			    edge: pick data 3
			    min-size: 1x1 * pick data 4 ; can be a width
			    
;			    v?? position
;			    v?? dimension
;			    v?? edge
;			    v?? min-size
;			    
			    
			    plug/liquid: switch/default edge [
			    	; synonym for bottom
			    	horizontal [
			    		( dimension * 1x0) + (min-size * -1x1)
			    	]
			    	; synonym for right
			    	vertical [
			    		( dimension * 0x1) + (min-size * 1x-1)
			    	]
			    ][0x0]
				
				
				;vout
			]
			
			
			;-----------------
			;-        materialize()
			;-----------------
			materialize: func [
				frame
			][
				vin [{glass/!} uppercase to-string frame/valve/style-name {[} frame/sid {]/materialize()}]
				frame/material/inner-offset: liquify*/fill !plug frame/material/inner-offset
				frame/material/v-max: liquify* epoxy-lib/!y-from-pair
				frame/material/v-visible: liquify* epoxy-lib/!y-from-pair
				frame/material/h-max: liquify* epoxy-lib/!x-from-pair
				frame/material/h-visible: liquify* epoxy-lib/!x-from-pair
				vout
			]
			
			
			
			;-----------------
			;-        gl-fasten()
			;-----------------
			gl-fasten: func [
				frame
				/local mtrl aspects
			][
				vin [{glass/!} uppercase to-string frame/valve/style-name {[} frame/sid {]/gl-fasten()}]
				
				mtrl: frame/material
				aspects: frame/aspects
				
				
				; mutate scrollers
				frame/v-scroller/material/position/valve: !place-at-edge/valve
				frame/v-scroller/material/dimension/valve: !dimension-at-edge/valve
				frame/h-scroller/material/position/valve: !place-at-edge/valve
				frame/h-scroller/material/dimension/valve: !dimension-at-edge/valve
				
				; mutate inner-frame
				;frame/inner-frame/material/dimension/valve: epoxy-lib/!pair-max/valve
				
				; mutate ourself
				mtrl/content-dimension/valve: epoxy-lib/!pair-subtract/valve
				mtrl/origin/valve: epoxy-lib/!pair-add/valve
				mtrl/inner-offset/valve: epoxy-lib/!negated-integers-to-pair/valve


				; allocate borders around ourself.
				link*/reset mtrl/content-dimension reduce [
					mtrl/dimension
					mtrl/border-size
					mtrl/border-size
					aspects/scroller-sizes
				]
				
				
				; setup our origin
				link*/reset mtrl/origin reduce [mtrl/position mtrl/border-size]
				


				; position scrollbars
				link*/reset frame/v-scroller/material/position reduce [
					mtrl/position
					mtrl/dimension 
					frame/v-scroller/material/orientation
					aspects/scroller-sizes
				]
				link*/reset frame/h-scroller/material/position reduce [
					mtrl/position
					mtrl/dimension 
					frame/h-scroller/material/orientation
					aspects/scroller-sizes
				]

				; dimension scrollbars
				link*/reset frame/v-scroller/material/dimension reduce [
					mtrl/position
					mtrl/dimension 
					frame/v-scroller/material/orientation
					aspects/scroller-sizes
				]
				link*/reset frame/h-scroller/material/dimension reduce [
					mtrl/position
					mtrl/dimension 
					frame/h-scroller/material/orientation
					aspects/scroller-sizes
				]

				; position content-frame
				link*/reset frame/inner-frame/material/position mtrl/origin
				
				; dimension content-frame
				link*/reset frame/inner-frame/material/dimension reduce [mtrl/content-dimension frame/inner-frame/material/min-dimension]

				;fill* frame/inner-frame/material/dimension 400x200

				; setup scroller ranges
				fill* frame/v-scroller/aspects/minimum 0
				link*/reset mtrl/v-max frame/inner-frame/material/min-dimension
				link*/reset frame/v-scroller/aspects/maximum mtrl/v-max
				
				link*/reset mtrl/v-visible mtrl/content-dimension
				link*/reset frame/v-scroller/aspects/visible mtrl/v-visible

				fill* frame/h-scroller/aspects/minimum 0
				link*/reset mtrl/h-max frame/inner-frame/material/min-dimension
				link*/reset frame/h-scroller/aspects/maximum mtrl/h-max
				
				link*/reset mtrl/h-visible mtrl/content-dimension
				link*/reset frame/h-scroller/aspects/visible mtrl/h-visible
;
;
;				; link offset to scrollbars
				link*/reset mtrl/inner-offset reduce [
					frame/h-scroller/aspects/value
					frame/v-scroller/aspects/value
				]
;
;				;fill* frame/temp-label/material/position 40x20
;				;link*/reset frame/temp-label/aspects/label mtrl/origin
;				
				link*/reset frame/inner-frame/material/translation mtrl/inner-offset

;				frame/valve/fasten frame

				fill* frame/h-scroller/aspects/value 0
				fill* frame/v-scroller/aspects/value 0

				vout
			]
			
			
		]
	]
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %scroll-frame.r 
    date: 20-Jun-2010 
    version: 1.0.0 
    slim-name: 'scroll-frame 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: SCROLL-FRAME
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: PANE  v1.0.0
;--------------------------------------------------------------------------------

append slim/linked-libs 'pane
append/only slim/linked-libs [


;--------
;-   MODULE CODE




;- slim/register/header
slim/register/header [

	; declare words so they stay bound locally to this module
	!plug: liquify*: !glob: content*: fill*: link*: unlink*: detach*: none
	
	; sillica lib
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: none
	prim-bevel: prim-x: prim-label: none
	include: none

	layout*: get in system/words 'layout
	
	

	;- LIBS
	glob-lib: slim/open/expose 'glob none [!glob]
	liquid-lib: slim/open/expose 'liquid none [
		!plug 
		[liquify* liquify ] 
		[content* content] 
		[fill* fill] 
		[link* link] 
		[unlink* unlink] 
		[detach* detach] 
	]
	sillica-lib: sl: slim/open/expose 'sillica none [
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		prim-bevel
		prim-x
		prim-label
		include
	]
	epoxy-lib: slim/open/expose 'epoxy none [!box-intersection]

	
	frame-lib: slim/open 'frame none
	

	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;

	
	
	;--------------------------------------------------------
	;-   
	;- !PANE[ ]
	!pane: make frame-lib/!frame [
	
		;-    aspects[ ]
		aspects: make aspects [
			;-        color:
			; a transprent bg by default.
			color: 0.0.0.255
			
			;-        h-offset:
			h-offset: none
			
			;-        v-offset:
			v-offset: none
			
			;-        backplane-clr:
			; usually you don't need to touch this.
			backplane-clr: 0.0.0.255
			
		]
		
		
		;-    material[ ]
		material: make material [
			;-        raster:
			raster: none
			
			;-        backplane:
			backplane: none
			
			
			;-        translation:
			translation: 0x0
			
			;-        translation-origin:
			;translation-origin: 0x0
			
			
		]


		;-    spacing-on-collect:
		; when collecting marbles, automatically set their offset to this value
		; in groups, usually you want content to be juxtaposed.
		spacing-on-collect: 5x5
		
		
		;-    layout-method:
		; most groups are horizontal
		layout-method: 'row

		
		
		;-    view-face:
		;
		; the face we use to render the image with.
		view-face: none


		;-    collect-in-frame:
		; pane uses the optional collection management, where marbles are collected in another
		; frame than ourself, and we let the style manage how that frame links into ours.
		collect-in-frame: none
		

		;-    rasterizer:
		;
		; the node which renders the pane-frame as an image.
		rasterizer: none
		
		
		;-    pixel-map:
		;
		; the node which renders the pane's back-plane as an image.
		;pixel-map: none
		
		
		;-    valve []
		valve: make valve [

			type: '!marble


			;-        style-name:
			style-name: 'pane
		

			;-        fg-glob-class:
			; no need for any globs.  just sizing fastening and automated liquification of grouped marbles.
			fg-glob-class: none

			;-        bg-glob-class:
			; class used to allocate and link a glob drawn BEHIND the marble collection
			bg-glob-class: make !glob [
				valve: make valve [
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup  these will be stored within the instance under input
						position !pair (random 200x200)
						dimension !pair (300x300)
						color !color
						;frame-color  !color (random white)
						; uncomment to debug
;						clip-region !block ([0x0 1000x1000])
;						min-dimension !pair
;						content-dimension !pair
;						content-min-dimension !pair
						backplane !any
						raster !any
					]
					
					;-            glob/gel-spec:
					gel-spec: [
						; event backplane
						position backplane 
						[
							image (data/position=) (data/backplane=)
						
						]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						
						; FG LAYER
						position raster dimension backplane ;color frame-color
						;------
						; uncomment following for debugging
						;
						;   min-dimension content-dimension content-min-dimension
						;------
						[
							; here we restore our parent's clip region  :-)
							;clip (data/parent-clip-region=)
							
							image (data/position=) (data/raster=)
							;image (data/position=) (data/backplane=)
							
							;fill-pen none ;(data/color=)
							;pen black ; (data/frame-color=)
							;line-width 1
							;pen red
							;box (data/position=) (data/position= + data/dimension= - 1x1) 0
							
							
							
							;------
							; uncomment for debugging purposes.
							;	line-width 1
							;	pen blue 
							;	fill-pen (0.0.0.129 + data/color=)
							;	box (data/position=) (data/position= + data/content-dimension=)
							;	pen red 
							;	fill-pen (0.0.0.129 + data/color=)
							;	box (data/position=) (data/position= + data/dimension=)
							;	pen black 
							;	fill-pen (0.0.0.129 + data/color=)
							;	box (data/position=) (data/position= + data/min-dimension=)
							;	pen white 
							;	fill-pen (0.0.0.129 + data/color=)
							;	box (data/position=) (data/position= + data/content-min-dimension=)
							;------
						
						]
						
						
						; controls layer
						;[]
						
						
						; overlay 
						;[]
					]
				]
			]

			;-----------------
			;-        materialize()
			;-----------------
			materialize: func [
				pane
				/local mtrl
			][
				vin [{materialize()}]
				mtrl: pane/material 
				pane/rasterizer: liquify* glob-lib/!rasterizer
				mtrl/raster: pane/rasterizer
				
				mtrl/backplane: liquify* glob-lib/!rasterizer
				
				
				pane/view-face: make sl/empty-face [pane: copy []]
				mtrl/translation: liquify* epoxy-lib/!to-pair


				; link up vertical and horizontal offset aspects.
				; note that if the application overides this, fasten is not performed, so the 
				; app setup will not be reset.
				link* mtrl/translation reduce [
					pane/aspects/h-offset
					pane/aspects/v-offset
				]
				
				

				vout
			]
			
			

			;-----------------
			;-        pre-specify()
			;-----------------
			pre-specify: func [
				pane [object!]
				stylesheet [block!]
			][
				vin [{pane/pre-specify()}]
				unless pane/collect-in-frame [
					vprint "column allocating"
					pane/collect-in-frame: sl/alloc-marble/using 'column compose [
						layout-method: (pane/layout-method)
						tight
					] stylesheet
					
					
					vprobe pane/collect-in-frame/sid
					
					pane/collect-in-frame/material: make pane/collect-in-frame/material [
						translation: liquify*/link !plug pane/material/position
					]
					
					vprint "column allocated"
					fill* pane/collect-in-frame/aspects/offset 0x0
					
					
					; this is a hack which allows use to go up the frame tree, but remember that the pane's collection
					; DOESN'T include the collect-in-frame directly
					pane/collect-in-frame/frame: pane

					
				]
				vout
			]
			
			;-----------------
			;-        post-specify()
			;-----------------
			post-specify: func [
				pane [object!]
				stylesheet [block!]
			][
				vin [{pane/post-specify()}]
				vprobe content* pane/collect-in-frame/material/dimension
				vprobe content* pane/material/content-dimension
				vprobe content* pane/collect-in-frame/material/content-dimension
				vprobe content* pane/collect-in-frame/material/origin
				vprobe content* pane/aspects/color
				vout
				pane
			]
			
			;-----------------
			;-        fasten()
			; this is a style-specific fastening extension.
			;
			; here we will link up the collect-in-frame with pane values,
			; and will link the raster to pane's glob.
			;
			; we also setup translation so it can be calculated by event mechanism.
			;-----------------
			fasten: func [
				pane
				/local rst cif img mtrl cmtrl bkpln
			][
				vin [{pane/fasten()}]
				vprobe content* pane/collect-in-frame/material/dimension
				vprobe content* pane/material/content-dimension
				vprobe content* pane/collect-in-frame/material/content-dimension
				vprobe content* pane/collect-in-frame/material/origin
				vprobe content* pane/aspects/color
				
				
				rst: pane/rasterizer
				cif: pane/collect-in-frame
				mtrl: pane/material
				cmtrl: cif/material
				bkpln: mtrl/backplane
				
				cif/valve/gl-fasten cif
				
				; mutate collect-in-frame and assign its dimension...
				cmtrl/dimension/valve: epoxy-lib/!pair-max/valve
				
				link*/reset  cmtrl/dimension reduce [
					mtrl/dimension
					cmtrl/min-dimension
				]
				
				; inherit collection-related material from c-i-f
				link*/reset mtrl/min-dimension cmtrl/min-dimension
				link*/reset mtrl/fill-weight cmtrl/fill-weight
				link*/reset mtrl/fill-accumulation cmtrl/fill-accumulation
				
				; link up raster
				link*/reset rst reduce [
					mtrl/dimension
					mtrl/translation
					pane/aspects/color
					pane/collect-in-frame/glob/layers/2
				]
				
				; link up backplane
				link*/reset bkpln reduce [
					mtrl/dimension
					mtrl/translation
					pane/aspects/color
					pane/collect-in-frame/glob/layers/1
				]
				
				vout
			]
			
			
			
		]
	]
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %pane.r 
    date: 20-Jun-2010 
    version: 1.0.0 
    slim-name: 'pane 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: PANE
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: STYLE-TOGGLE  v0.5.3
;--------------------------------------------------------------------------------

append slim/linked-libs 'style-toggle
append/only slim/linked-libs [


;--------
;-   MODULE CODE



;- slim/register/header
slim/register/header [
	; declare words so they stay bound locally to this module

	layout*: get in system/words 'layout
	
	

	;- LIBS
	to-color: none
	
	!glob: none
	glob-lib: slim/open/expose 'glob none [!glob to-color]
	
	marble-lib: slim/open 'marble none
	button-lib: slim/open 'style-button none
	event-lib: slim/open 'event none
	
	!plug: liquify*: content*: fill*: link*: unlink*: none
	liquid-lib: slim/open/expose 'liquid none [
		!plug 
		[liquify* liquify ] 
		[content* content] 
		[fill* fill] 
		[link* link] 
		[unlink* unlink] 
		[dirty* dirty]
	]
	
	
	prim-bevel: prim-x: prim-label: prim-knob: none
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: none
	top-half: bottom-half: none
	sillica-lib: sl: slim/open/expose 'sillica none [
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		prim-bevel
		prim-x
		prim-label
		prim-knob
		top-half
		bottom-half
	]
	epoxy-lib: slim/open/expose 'epoxy none [!box-intersection]

	

	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;

	;--------------------------------------------------------
	;-   
	;- !TOGGLE[ ]
	!toggle: make button-lib/!button [
	
		;-    Aspects[ ]
		aspects: make aspects [
			engaged?: false
		]

		
		;-    Material[]
		material: make material []
		
		
		;-    radio-list:
		; when this is filled with a block containing other marbles,
		; they will automatically be switched to off when this one is set to on.
		radio-list: none
		
		
		;-    valve[ ]
		valve: make valve [
		
			type: '!marble
		
			;-        style-name:
			; used as a label for debugging and node browsing.
			style-name: 'toggle  
			
			
			;-        label-font:
			; font used by the gel.
			;label-font: theme-knob-font
			
			;-        glob-class:
			; defines the glob which will be built by each marble instance.
			;   glob-class/marble  is added automatically by setup.
			glob-class: make !glob [
				pos: none
				
				valve: make valve [
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup these will be stored within glob/input
						position !pair (random 200x200)
						dimension !pair (100x30)
						color !color  (random white)
						label-color !color  (random white)
						label !string ("")
						focused? !bool
						hover? !bool
						selected? !bool
						engaged? !bool
						align !word
						padding !pair
						font !any
					]
					
					;-            glob/gel-spec:
					; different AGG draw blocks to use, one per layer.
					; these are bound and composed relative to the input being sent to glob at process-time.
					gel-spec: [
						; event backplane
						position dimension 
						[
							line-width 1 
							pen none 
							fill-pen (to-color gel/glob/marble/sid) 
							box (data/position=) (data/position= + data/dimension= - 1x1)
						]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						position dimension color label-color label align hover? engaged? focused? selected? padding font
						[
							(
								;print [ data/label= ": " data/label-color= data/color=]
								;draw bg and highlight border?
								any [
									all [
										data/engaged?= 
										compose [
										
											; bg color
											pen black
											fill-pen white
											line-width 1
											box (data/position=) (data/position= + data/dimension= - 1x1) 3
											
											;inner shadow
											pen (shadow + 0.0.0.25)
											line-width 2
											fill-pen none
											box (data/position= + 1x1) (data/position= + data/dimension= - 2x2) 2
	
											; erase lower inner-shadow
											pen white
											fill-pen white
											line-width 2
											box ( bottom-half data/position=  + 3x-2 data/dimension= + -6x0) 2
											
											pen none
											(sl/prim-glass/corners/only (data/position= + 1x2) (data/position= + data/dimension= - 1x1) theme-color 190 2)
										]
;										compose [
;											; bg color
;											pen none
;											fill-pen white
;											
;											box (data/position= + 1x1) (data/position= + data/dimension= - 2x2) 2
;											
;											pen none
;											line-width 0
;											;fill-pen linear (data/position=) 1 (data/dimension=/y) 90 1 1 ( data/color= * 0.6 + 128.128.128) ( data/color= ) (data/color= * 0.7 )
;											;fill-pen linear (data/position=) 1 (data/dimension=/y) 90 1 1 ( data/color= + 10.10.10 ) ( data/color= * 0.7) (data/color= * 0.6 )
;											
;											;fill-pen linear (data/position=) 1 (data/dimension=/y) 90 1 1 ( data/color=  ) ( data/color= * 0.9) (data/color= * 0.7 )
;;											fill-pen linear (data/position=) 1 (data/dimension=/y) 90 1 1 ( data/color=  ) (data/color= * 0.7 ) ( data/color= * 0.9) ( data/color=  )
;;											fill-pen radial (data/position=) 1 (data/dimension=/y) 90 1 1 (data/color= * 0.7 ) ( data/color=  ) ( data/color=  ) ( data/color= * 0.9)
;
;;											box (data/position= + 1x1) (data/position= + data/dimension= - 1x1) 2
;;											line-width 0
;;											fill-pen radial (data/position= + (data/dimension= / 2) + 0x1) 1 (data/dimension=/x * 0.6) 0 1 (data/dimension=/y / data/dimension=/x) 
;;											    ( data/color=  )
;;											    ( data/color= * 0.9)
;;											    ( theme-glass-color + 0.0.0.200)
;;											box (data/position= + 1x1) (data/position= + data/dimension= - 1x1) 2
;
;											fill-pen radial (data/position= + (data/dimension= / 2) + 0x1 ) 1 (data/dimension=/x * 0.754) 0 1 (data/dimension=/y / data/dimension=/x) 
;											    ( white  )
;											    ( (white * 0.5) + ( theme-glass-color * 0.5 ) + 0.0.0.100 )
;											    ( theme-glass-color + 0.0.0.100)
;											box (data/position= + 1x1) (data/position= + data/dimension= - 1x1) 2
;											
;											; shine
;											pen none
;											fill-pen (data/color= * 0.7 + 140.140.140.210)
;											box ( top-half  data/position= data/dimension= + 0x1) 2
;	
;											; border
;											fill-pen none
;											line-width 1
;											pen  theme-knob-border-color
;											box (data/position= ) (data/position= + data/dimension= - 1x1) 3
;
;										]
									]
									
;									all [ data/hover?= compose [
;										; slight shadow
;										pen shadow
;										line-width 2
;										fill-pen none
;										box (data/position= + 2x2) (data/position= + data/dimension= - 2x0) 4
;										
;											pen white
;											line-width 1
;											fill-pen linear (data/position=) 1 (data/dimension=/y) 90 1 1 ((data/color= * 0.8) + (white * .3)) ((data/color= * 0.8) + (white * .3 )) ((data/color= * 0.8) + (white * .1))
;											box (data/position= + 2x2) (data/position= + data/dimension= - 3x3) 4
;											; shine
;											pen none
;											fill-pen (data/color= * 0.7 + 140.140.140.128)
;											box ( top-half  data/position= data/dimension= ) 4
;
;											; border
;											fill-pen none
;											line-width 1
;											pen  theme-knob-border-color
;											box (data/position= ) (data/position= + data/dimension= - 1x1) 5
;
;										]
;									]
									
									; default
									compose [
										(
											prim-knob 
												data/position= 
												data/dimension= - 1x1
												data/color=
												theme-knob-border-color
												'horizontal ;data/orientation=
												1
												4
										)
									]
								]
							)
							(
							either data/hover?= [
								compose [
									line-width 1
									pen none
									fill-pen (theme-glass-color + 0.0.0.200)
									;pen theme-knob-border-color
									box (data/position= + 3x3) (data/position= + data/dimension= - 3x3) 2
								]
							][[]]
							)
							line-width 2
							pen none ;(data/label-color=)
							fill-pen (data/label-color=)
							; label
							(prim-label/pad data/label= data/position= + 1x0 data/dimension= data/label-color= data/font= data/align=  data/padding=)
							
							
							
						]
							
						; controls layer
						;[]
						
						; overlay layer
						; like the bg, it may switched off, so don't depend on it.
						;[]
					]
				]
			]
			
			
			
			
			
			;-----------------
			;-        button-handler()
			;-----------------
			button-handler: func [
				event [object!]
				/local button state marble
			][
				vin [{HANDLE BUTTON}]
				vprint event/action
				button: event/marble
				
				switch/default event/action [
					start-hover [
						fill* button/aspects/hover? true
					]
					
					end-hover [
						fill* button/aspects/hover? false
					]
					
					select [
						;print "button pressed"
						fill* button/aspects/selected? true
						;probe content* button/aspects/label
						;probe button/actions
						;event/action: 'engage
						state: content* button/aspects/engaged?
						
						either block? button/radio-list [
							;probe length? button/radio-list
							foreach marble button/radio-list [
								either same? marble button [
									;print "Not"
									fill* button/aspects/engaged? not state
								][
									;print "same!"
									fill* marble/aspects/engaged? false
								]
							]
						][
							fill*  button/aspects/engaged? not state
						]
						button/valve/do-action event
						;ask ""
					]
					
					; successfull click
					release [
						;fill* button/aspects/selected? false
						;do-action event
					]
					
					; canceled mouse release event
					drop no-drop [
						;fill* button/aspects/selected? false
						;do-action event
					]
					
					swipe [
						fill* button/aspects/hover? true
						;do-action event
					]
				
					drop? [
						fill* button/aspects/hover? false
						;do-action event
					]
				
					focus [
;						event/marble/label-backup: copy content* event/marble/aspects/label
;						if pair? event/coordinates [
;							set-cursor-from-coordinates event/marble event/coordinates false
;						]
;						fill* event/marble/aspects/focused? true
					]
					
					unfocus [
;						event/marble/label-backup: none
;						fill* event/marble/aspects/focused? false
					]
					
					text-entry [
;						type event
					]
				][
					vprint "IGNORED"
				]
				
				; totally configurable end-user event handling.
				; not all actions are implemented in the actions, but this allows the user to 
				; add his own events AND his own actions and still work within the API.
				event/marble/valve/do-action event
				
				vout
				none
			]
			
			;-----------------
			;-        post-specify()
			;-----------------
			post-specify: func [
				toggle
				stylesheet
			][
				vin [{post-specify()}]
				if block? toggle/radio-list [
					append toggle/radio-list toggle
				]
				vout
			]
			
			

			;-----------------
			;-        setup-style()
			;-----------------
			; a callback to extend anything in the marble AFTER Glass has finished with its own setup
			;
			; this is used by styles for their own custom data requirements.
			;
			; styles may also provide application setup hooks, but usually do so via extensions to the
			; the specification parser, using dialect()
			; 
			; some styles will also add default stream handlers (like viewports)
			;-----------------
			setup-style: func [
				marble
			][
				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/stylize()}]
				
				; just a quick stream handler for all marbles
				event-lib/handle-stream/within 'button-handler :button-handler marble
				vout
			]
		]
	]
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %style-toggle.r 
    date: 25-Jun-2010 
    version: 0.5.3 
    slim-name: 'style-toggle 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: STYLE-TOGGLE
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: STYLE-ICON-BUTTON  v1.0.1
;--------------------------------------------------------------------------------

append slim/linked-libs 'style-icon-button
append/only slim/linked-libs [


;--------
;-   MODULE CODE



;- slim/register/header
slim/register/header [
	; declare words so they stay bound locally to this module

	layout*: get in system/words 'layout
	
	

	;- LIBS
	to-color: none
	
	!glob: none
	glob-lib: slim/open/expose 'glob none [!glob to-color]
	
	marble-lib: slim/open 'marble none
	button-lib: slim/open 'style-button none
	event-lib: slim/open 'event none
	
	!plug: liquify*: content*: fill*: link*: unlink*: none
	liquid-lib: slim/open/expose 'liquid none [
		!plug 
		[liquify* liquify ] 
		[content* content] 
		[fill* fill] 
		[link* link] 
		[unlink* unlink] 
		[dirty* dirty]
	]
	
	
	prim-bevel: prim-x: prim-label: prim-knob: none
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: none
	top-half: bottom-half: none
	sillica-lib: sl: slim/open/expose 'sillica none [
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		prim-bevel
		prim-x
		prim-label
		prim-knob
		top-half
		bottom-half
	]
	epoxy: slim/open/expose 'epoxy none [!box-intersection]
	glue-lib: slim/open 'glue none

	
	; we do not load the icon-lib immediatetly, since we cannot guess what 
	; icon set the app needs.
	;
	; instead, whenever the dialect detects an icon, it will load the lib dynamically
	; expecting the user to have select the set if its not the default.
	icon-lib: none

	
	
	
	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;
	;-    default-icon:
	; this is the default glass marble image
	default-icon: make image! [32x32 #{
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000009BB3B9
7B96AE6E8EB06B8EB3799BBB8FAEC3ADC4C8C9D8D1000000000000000000
000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000009CB3BD
5B7FB54774BD4B7EC84E89D24E88D1508BD15691D76396D27DA7D0ACC6D5
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000D1E2D8
80A0C24F7FC6548CCC5F96D4619CDD639DE35D9CDE60A0E266A4E768A3E4
6AA5E770A5E598BEDCC9DBD5000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
D6E5DE7FA2CD5388D16198D769A0DB6AA4E067A4E566A2E85FA1E964A4EB
68A6EB6BA9EC6DACEC6EAEEF72AEF097C2E8CCDDD4000000000000000000
000000000000000000000000000000000000000000000000000000000000
0000000000009CB5CE5B8CD4679AD975A8E180B4EB7EB3EE74AEEB63A2E6
5C9EE561A1E561A4E966A9EE6CACEF6FB0F274B5F479B7F9A4CAE8000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000C4D6D46C97CF6698DB7AAAE492BFF095C3F28FBFF1
83BAEF63A3E95FA0E863A3EB61A6ED64A7ED66AAEE6CADF171B3F576B8FB
86C2FCB4CED66B8D8E171719000000000000000000000000000000000000
000000000000000000000000000000A1BBD26596D670A2E08DBCF19FCBF7
A2CEF59AC8F589BEF560A4F05CA4F061A6F162A7F264AAF166A8EF68ACF2
6FB1F678B7F981C2FF9ECCEC5F7A7C566C6F526A6B1B1C1F151618000000
000000000000000000000000000000000000D8E8DF89AAD2679BDB79ACE4
97C3F5A4CFF9AED8F8A1CFF97DB9F55BA1F15BA4F05FA6F061A6F364A9F3
67AAF167ABF16EB0F774B5F77EBDFB92CBFC80979A5C75765973745A7676
171719161618000000000000000000000000000000000000D0E1DF7FA6D3
6B9EDD7CAFEB94C3F59ECBF7A1CFF998C9FA74B0F35B9FEF5FA2EC62A5EE
65A7F365A9F565ABF367AAEE6AACF472B4F97CBEFC90CDFF98B4C2597072
576D6F5971733E4C4F1F1E211D1C1F1A1A1E19191B000000000000000000
C9DDDB7DA6D46EA2DE77ABE88ABBEF93C3F291C1F584BAF563A5ED62A7F0
5699E05C9FEC65A5F163A8F262A7F263A7EE69ACF272B5F97FC0FE8DCCFF
93B8CC617B7F54686A4C5C5F4D5F623A46491E1F221D1D201D1D20000000
000000000000CADFDD83A9D474A6DF6EA8E47BB1E984B7EB80B5EE6BA8EC
559CE75D9FE85499E4589EE85CA3EC60A4EE65A6EF65A7EE69ACF372B5F9
80C2FD8BCDFF8CB5CF72929D607A82566B704451544F6264222226212125
2021241E1E22000000000000D4E7E18AAED57AA8E06BA6E36DA7E470A8E7
6CA6E7579BE65097E65A9AE55FA0E75EA1EC5CA0EC60A3ED66A5ED67A6EE
69ACF274B6FA82C4FE8CCCFF88B2CE7CA0B57292A5678392566A744F6267
383F4328282C26262A232327000000000000E2F1E997B7D479A9DF75A8E0
69A4E2629FE25C9BE25296E25898E45D9DE65C9FE85C9FEC5EA0EC62A3ED
67A5F166A9EE6CB0F478BAFA86C7FF88C7FE89B5D182ABC77DA3BE7799B3
6D8CA35C7280434D552E2E332D2E3229292E000000000000000000B2CAD5
7CA8DA7BAAE273A7E562A0E15596DD5395E05495E45A99E65A9BE95C9FE8
5DA1E963A3F068ABF46DADF072B2F57EBFFC88C5FF89C4F696C9DD86B4D3
7EABCC7EA5C5789CB86C89A05A6F7E3B4047323338303035000000000000
000000D6E5E28BAED17AAEE477AAE676A9E869A3E6609BDF5D99E35A99E4
5A9DE75DA1E862A2E76CABF16FAEF470AFF279B8FA81C1FF79B5F6AAE2F3
A6DBE88DC0DF7DADD57BA6CA7DA1C27698B36A859A4C576335353C34353A
000000000000000000000000B3C8CE7DA9D47AB0E978ABE673AAE76CA6E8
69A0E564A0E563A3E766A3E969A6E96FACED71B0F378B7FA7FC0FD79B3ED
8EC9F3B9F1F0ACE3EA94C8E27DAFD979A6CD7BA1C2799BB97291A95D7285
3F454D36373C000000000000000000000000E0F2E89CB2B877A0CB7BB0E5
76AFE874ACEC6FA8E96CA6EB6AA6ED6BA9EC6DACEF74B2F47AB9FC7BB9F3
69A0D982BAE8BFF3F5B9EFEFADE2E794C6DE7DAED775A3CC769CBD779AB7
7494AE677F974D57653A3B40000000000000000000000000010101D3E5DC
9AAAAF7391AF73A1CC74A9E172ADE973ADF076B0F273AFEE71B0EE70A7D6
618AB15480AF78B1DEC0F6F7BEF1F1B3EAEAA7DADF8DBCD67AA8D0739FC7
7397B87595B17392AC6B869D58687A434952000000000000000000000000
0403045A7173B2C8C1ABBDBE7D929E67829660839C6387A75C83A35F89AE
5471883C4B5B4C6E9B8EC8E6BAF0F3BBEFF0B4EAE9ABDEE099C8D583AECE
75A2CA6F98BF6F91B27190AA708DA76C87A05F7487515C6B000000000000
000000000000030303586F71617E805E787AA2B7B696A8AB717F825B6669
5159654F5E6C4E5F756992BE97CEE3A6D9E2ABE0E5AADEE3A2D4DB96C4D4
85B0CC78A2C8719BC56B92BA6C8EB06E8BA76F8BA56A849D647A90657D93
0000000000000000000000000000002323273D4C4F638182546B71607987
56697645597049668F516F996284A8739EBD7DABC78AB8CE93C3D393C1D0
8CB7CB82ACC47AA2C2739AC06B91BA698EB46A8BAC6D89A56E89A26C87A0
69839B7291AD0000000000000000000000000000001C1C1F212125495D5E
3A484E44545E4A5A664C5F74526A895E7B9B6B8DAF6D91AF6A90AE7198B5
78A0BA7AA1BB789EB97297B46B8FB16688AC6688AC6686A766819E677F96
677F966881986F8BA67FA6C600000000000000000000000000000018181B
22222618191B18191B2B3138353D443E485347525F576674607487596E85
5268825A7490607C9763809D617C995F79955D76925F7894607A97617994
5E71865B687A55627161768A7CA1C18CBAE0000000000000000000000000
00000000000025252918181A1516181D1D1F21212533384035383F34343A
39393E3D3E4444465049505D4B55664D586A4D56654F5766515D6D566477
576779576578545F6E505B674E576353616F779AB88CBAE0000000000000
00000000000000000000000000000000000012121319191C1E1E20353C44
3A404831313637383D3C3C4240404744444B46474E48485047485047484F
4B505A525C695A697A5B6C7C5563723D3E44464C565565758CBAE08CBAE0
000000000000000000000000000000000000000000000000000000141517
1B1C1E1F1F22404B542D2D3333343938383E3B3B423F404642434A44454C
45464D45464E525A6644454C5561703F3F463D3D443B3B424D596761798F
8CBAE08CBAE0000000000000000000000000000000000000000000000000
0000000000001314164E64684F636854676F566972556873566775515E6A
535F6C607585617585698295708DA47493AE657D93657C92647B9162798F
60778D000000000000000000
} #{
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFB5
755A335772B2FDFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFA9
24000000000000001EA0
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFF7
5A000000000000000000
000054F4FFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FD450000000000000000
00000000003CFAFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFF7200000000000000
000000000000000069FF
FFFFFFFFFFFFFFFFFFFF
FFFFFFDC030000000000
00000000000000000000
03CBFCFFFFFFFFFFFFFF
FFFFFFFFFF6600000000
00000000000000000000
00000053F6FAFDFFFFFF
FFFFFFFFFFFFFD120000
00000000000000000000
000000000008E9F5F8FB
FEFFFFFFFFFFFFFFD600
00000000000000000000
0000000000000000C1EE
F1F5FBFEFEFFFFFFFFFF
B8000000000000000000
00000000000000000000
9EE4ECF0F5FAFCFEFFFF
FFFFB500000000000000
00000000000000000000
00008ACEDAE7F0F5FAFC
FDFFFFFFD00000000000
00000000000000000000
0000000077A2B4CEE4EE
F7FBFDFFFFFFF7090000
00000000000000000000
0000000000015D7187A5
C7E0EFF9FCFEFFFFFF4E
00000000000000000000
000000000000000B384B
5C769FC2E1F3F8FCFFFF
FFC10000000000000000
00000000000000000012
223041587AA2CAE7F3FB
FFFFFFFF4E0000000000
00000000000000000000
04151F2C3B4D6886AFD6
EBF8FFFFFFFFEE230000
00000000000000000000
00010F162232404F687E
9DC5E5F6FFFFFFFFFFDE
2C000000000000000000
0000020D131E2E3E4A5B
71879FBFE0F6FFFFFFFF
FFFDED65060000000000
0000010C1719202E414D
57667C90A7C4E4F8FFFF
FFFFFFFDF9F6D2733110
00060E273B3731313B48
565E6977889FB5CEE9FA
FFFFFFFFFFFEFBF7F3EA
D4BA90645059625A5554
5B666D75838D9CB1C3D7
ECFAFFFFFFFFFFFEFDF9
F7F3EADBC4A38988918B
8281848A929AA2AAB7C6
D5E2F0FAFFFFFFFFFFFF
FDFBFAF7F3EFE6D7CAC9
C8BFB4B4B5B9BFC2C7CF
D6DDE7EEF6FCFFFFFFFF
FFFFFFFDFBF9F9F6F4F2
EEEBE5E1DEDCDDDEE2E6
E8EBEFEDF1F9FCFDFFFF
FFFFFFFFFFFFFEFBFBF9
F8F9F6F3F1F0EFEEEEF0
F3F5F6F7F9F8F8FDFEFF
FFFFFFFFFFFFFFFFFFFF
FDFCFBFDFCFAF9F8F8F9
F8FAFAFDFCFDFDFDFCFE
FFFFFFFFFFFFFFFFFFFF
FFFFFFFDFDFDFDFDFDFC
FCFBFBFAFBFDFEFEFEFE
FEFFFFFF
}]
	
	
	
	
	
	
	


	;--------------------------------------------------------
	;-   
	;- !ICON[ ]
	!icon: make button-lib/!button [
	
		;-    Aspects[ ]
		aspects: make aspects [
			engaged?: false
			icon: default-icon
			options: [ simple ] ; this includes modes and hints for display.
			drawing: none ; this is a special AGG draw block you include over the rest, but under the shine.
			icon-spacing: 0x0 ; this adds space between the text and the icon (you shoudn't add any x component here, it must be a pair).
			padding: 3x3
			label: none
			size: -1x-1
			font: make font [bold?: false size: 10]
		]

		
		
		;-    Material[]
		material: make material [
			fill-weight: 0x0
		
			
			;-        icon-size:
			; this node will connect to the icon and return only its size.
			; this will thus force the button to add the icon's size to itself
			icon-size: none
			
			
			;-        label-size:
			; space setup for label (this will be used instead of usual min-dimension)
			; and min-dimension will be a pair-add node
			label-size: none
			
			
			;-        icon-spacing:
			; because materials have precedence in linking, this icon-space will be used instead
			; of the aspect.
			;
			; this will be linked to the aspect, but will be gated to that its only active
			; when there is a label
			icon-spacing: none
			
			;-        inside-size:
			; 
			; this is the custom calculated size of the icon icluding image, label and spacing, but not padding.
			;
			; padding is calculated in min-dimension directly.
			inside-size: none
			
			
		]
		
		;-    label-auto-resize-aspect:
		; this will resize the width based on the text, automatically.
		label-auto-resize-aspect: 'automatic
		
		
		;-    icon-set:
		; this will change the default icon set used when the DIALECT is evaluated.
		;
		; none uses the icons lib default
		;
		; use this to create substyles which refer to different icon sets by default.
		;
		; this can actually be the same icons but with different scalings or styles depending
		; on where they are used.
		icon-set: none
		
		
		
		;-    radio-list:
		; when this is filled with a block containing other marbles,
		; they will automatically be switched to off when this one is set to on.
		radio-list: none
		
		
		;-    valve[ ]
		valve: make valve [
		
			type: '!marble
		
			;-        style-name:
			; used as a label for debugging and node browsing.
			style-name: 'icon  
			
			
			;-        label-font:
			; font used by the gel.
			;label-font: theme-knob-font
			
			;-        glob-class:
			; defines the glob which will be built by each marble instance.
			;   glob-class/marble  is added automatically by setup.
			glob-class: make !glob [
				pos: none
				
				valve: make valve [
				
					;-----------------
					;-        mode()
					;-----------------
					mode: func [
						selected?
						label?
						icon?
					][
						any [
							all [selected? icon? label?  'both-down ]
							all [selected? icon? 'icon-down]
							all [selected? label? 'lbl-down]
							all [icon? label? 'both-up]
							icon? 'icon-up
							label? 'lbl-up
						]
					]
					
					; binding for gel spec
					tmp: none
				
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup these will be stored within glob/input
						position !pair (random 200x200)
						dimension !pair (100x30)
						color !color  (random white)
						label-color !color  (random white)
						label !string ("")
						focused? !bool
						hover? !bool
						selected? !bool
						engaged? !bool
						align !word
						padding !pair
						font !any
						icon !any ; MUST be an image! or none!
						          ; dimension will always add enough space for the image & text.
						label-size !any
						icon-spacing !any
					]
					
					;-            glob/gel-spec:
					; different AGG draw blocks to use, one per layer.
					; these are bound and composed relative to the input being sent to glob at process-time.
					gel-spec: [
					
					
						; event backplane
						position dimension 
						[
							line-width 1 
							pen none 
							fill-pen (to-color gel/glob/marble/sid) 
							box (data/position=) (data/position= + data/dimension= - 1x1)
						]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						position dimension color label-color label align hover? focused? selected? padding font icon label-size icon-spacing
						[
						
							
							
							; BG
							(
								either (data/selected?= and data/hover?=) [
									;probe "S"
									compose [
										; bg color
										pen black
										fill-pen white
										line-width 1
										box (data/position=) (data/position= + data/dimension= - 1x1) 3
										
										;inner shadow
										pen (shadow + 0.0.0.25)
										line-width 2
										fill-pen none
										box (data/position= + 1x1) (data/position= + data/dimension= - 2x2) 2

										; erase lower inner-shadow
										pen white
										fill-pen white
										line-width 2
										box ( bottom-half data/position=  + 3x-2 data/dimension= + -6x0) 2
										
										pen none
										(sl/prim-glass/corners/only (data/position= + 1x2) (data/position= + data/dimension= - 1x1) theme-color 190 2)
									]
								][[]]

							)
							(
								;probe data/hover?=
								either ((not data/selected?=) and data/hover?=) [
									;probe "H"
									compose [
										(
											prim-knob 
												data/position= 
												data/dimension= - 1x1
												data/color=
												theme-knob-border-color
												'horizontal ;data/orientation=
												1
												4
										)
									]
								][[]]
							)
							(
								either image? data/icon= [
									;probe "I"
									
									
									 tmp: (data/position= + (data/dimension= / 2 * 1x0) - (data/icon=/size / 2 * 1x0)  ) + 
									 	  ((data/dimension= - data/label-size= - data/icon-spacing= - data/icon=/size) / 2 * 0x1)
										
									compose [
										image (data/icon=) (tmp)
										; uncomment to put a red box around the icon. allows to debug sizing algorythm.
										;pen red
										;line-width 1
										;fill-pen none
										;box (tmp: (data/position= + (data/dimension= / 2 * 1x0) - (data/icon=/size / 2 * 1x0) + (data/padding= * 0x1) )) (tmp + data/icon=/size - 1x1 )
									]
								][[]]
							)
							
							(
							either data/hover?= [
								compose [
									line-width 1
									pen none
									fill-pen (theme-glass-color + 0.0.0.200)
									;pen theme-knob-border-color
									box (data/position= + 3x3) (data/position= + data/dimension= - 3x3) 2
								]
							][[]]
							)
							line-width 2
							pen none ;(data/label-color=)
							fill-pen (data/label-color=)
							; label
							(prim-label/pad data/label= data/position= + 1x0 data/dimension= data/label-color= data/font= 'bottom data/padding=)
							
							
							
						]
							
						; controls layer
						;[]
						
						; overlay layer
						; like the bg, it may switched off, so don't depend on it.
						;[]
					]
				]
			]
			
			
			
			
			;-----------------
			;-        post-specify()
			;-----------------
			post-specify: func [
				toggle
				stylesheet
			][
				vin [{post-specify()}]
				if block? toggle/radio-list [
					append toggle/radio-list toggle
				]
				vout
			]
			

			
			;-----------------
			;-        materialize()
			; style-oriented public materialization.
			;
			; called just after gl-materialize()
			;
			; note materializtion occurs BEFORE the globs are linked, so allocate any
			; material nodes it expects to link to here, not in setup-style().
			;
			; read the materialize() function notes above for more details, which also apply here.
			;-----------------
			materialize: func [
				icon
			][
				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/materialize()}]
				icon/material/icon-size: liquify* epoxy/!image-size
				icon/material/icon-size/mode: 'xy ; we only want to add height to the button.
				
				
				; swap the allocated min-dimension for label-size
				icon/material/label-size: icon/material/min-dimension
				
				; allocate a new min-dimension which will be linked to other space requirements.
				icon/material/min-dimension: liquify* epoxy/!pair-add
				icon/material/inside-size: liquify* epoxy/!vertical-accumulate
				
				icon/material/icon-spacing: liquify* glue-lib/!gate
				icon/material/icon-spacing/default-value: 0x0
				
				vout
			]
			
						

			;-----------------
			;-        setup-style()
			;-----------------
			; a callback to extend anything in the marble AFTER Glass has finished with its own setup
			;
			; this is used by styles for their own custom data requirements.
			;
			; styles may also provide application setup hooks, but usually do so via extensions to the
			; the specification parser, using dialect()
			; 
			; some styles will also add default stream handlers (like viewports)
			;-----------------
;			setup-style: func [
;				marble
;			][
;				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/stylize()}]
;				
;				; just a quick stream handler for all marbles
;				event-lib/handle-stream/within 'button-handler :button-handler marble
;				vout
;			]
			

			;-----------------
			;-        gl-fasten()
			; here we replace the gl-fasten, since we had to move min-dimension to some special setup
			;-----------------
			gl-fasten: func [
				marble
			][
				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/gl-fasten()}]
				
				; the automatic label resizing is optional in marbles.
				;
				; current acceptible values are ['automatic | 'disabled]
				if 'automatic = get in marble 'label-auto-resize-aspect [
					link*/exclusive marble/material/label-size marble/aspects/size
					link* marble/material/label-size marble/aspects/label
					link* marble/material/label-size marble/aspects/font
					;link* marble/material/label-size marble/aspects/padding
					;print "!!!!!!!!!!!!"
					;ask "@"
				]
				
				
				
				; perform any style-related fastening.
				marble/valve/fasten marble
				vout
			]


			;-----------------
			;-        fasten()
			;
			; style-oriented public fasten call.  called at the end of gl-fasten()
			;
			;-----------------
			fasten: func [
				icon
			][
				vin [{glass/!} uppercase to-string marble/valve/style-name {[} marble/sid {]/fasten()}]
				;print "F"
				;print "-->"
				;probe content* icon/material/label-size
				;probe content* icon/material/icon-size
				;probe content* icon/aspects/padding
				
				link*/reset  icon/material/icon-size icon/aspects/icon
				
				; we only have icon spacing when there is a label.
				link* icon/material/icon-spacing icon/aspects/icon-spacing
				link* icon/material/icon-spacing icon/aspects/label
				
				
				link* icon/material/inside-size icon/material/icon-size
				link* icon/material/inside-size icon/material/icon-spacing
				link* icon/material/inside-size icon/material/label-size
				
				
				link* icon/material/min-dimension icon/material/inside-size
				link* icon/material/min-dimension icon/aspects/padding
				link* icon/material/min-dimension icon/aspects/padding
				;probe content* icon/material/min-dimension
				;probe content* icon/aspects/label
				;print "<---"
				vout
			]
			
			

		
			;-----------------
			;-        dialect()
			;
			; this uses the exact same interface as specify but is meant for custom marbles to 
			; change the default dialect.
			;
			; note that the default dialect is still executed, so you may want to "undo" what
			; it has done previously.
			;
			;-----------------
			dialect: func [
				marble [object!]
				spec [block!]
				stylesheet [block!] "Required so stylesheet propagates in marbles we create"
				/local data img-count icon
			][
				vin [{dialect()}]
				img-count: 1
				
				;print "!"
				
				parse spec [
					any [
						set data issue! (
							unless icon-lib [ 
								icon-lib: slim/open 'icons none 
							]
							
							icon: icon-lib/get-icon/set to-word to-string data marble/icon-set
							
							link*/reset marble/aspects/icon icon
							
							unless string? content* marble/aspects/label [
								fill* marble/aspects/label icon-lib/icon-label data
							]
						)
						
						| 'no-label (
							fill* marble/aspects/label none
						)
						
						| set data image! (
							switch img-count [
								; sets the main image
								1 [
									fill* marble/aspects/icon data
									img-count: img-count + 1
								]
								
								; sets the push image
								2 [
									img-count: img-count + 1
								]
								
								; sets the hover image
								3 [
									img-count: img-count + 1
								]
							]
						)
						
						| skip
					]
				]

				vout
			]
		]
	]
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %style-icon-button.r 
    date: 14-Jan-2010 
    version: 1.0.1 
    slim-name: 'style-icon-button 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: STYLE-ICON-BUTTON
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: ICONS  v0.1.0
;--------------------------------------------------------------------------------

append slim/linked-libs 'icons
append/only slim/linked-libs [


;--------
;-   MODULE CODE


;- slim/register/header
slim/register/header [

	;- LIBS
	!plug: liquify*: content*: fill*: link*: unlink*: none
	liquid-lib: slim/open/expose 'liquid none [!plug [liquify* liquify ] [content* content] [fill* fill] [link* link] [unlink* unlink]]

	
	;- 
	;- GLOBALS
	;-    default-style:
	default-style: 'default
	
	;-    default-size:
	default-size: 32 ; MUST be an integer!
	
	;-    default-set:
	default-set: 'glass
	
	;-    root-path
	root-path: what-dir
	
	
	
	
	;-    default-icon:
	; this is the default glass marble image
	default-icon: make image! [32x32 #{
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000009BB3B9
7B96AE6E8EB06B8EB3799BBB8FAEC3ADC4C8C9D8D1000000000000000000
000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000009CB3BD
5B7FB54774BD4B7EC84E89D24E88D1508BD15691D76396D27DA7D0ACC6D5
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000D1E2D8
80A0C24F7FC6548CCC5F96D4619CDD639DE35D9CDE60A0E266A4E768A3E4
6AA5E770A5E598BEDCC9DBD5000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
D6E5DE7FA2CD5388D16198D769A0DB6AA4E067A4E566A2E85FA1E964A4EB
68A6EB6BA9EC6DACEC6EAEEF72AEF097C2E8CCDDD4000000000000000000
000000000000000000000000000000000000000000000000000000000000
0000000000009CB5CE5B8CD4679AD975A8E180B4EB7EB3EE74AEEB63A2E6
5C9EE561A1E561A4E966A9EE6CACEF6FB0F274B5F479B7F9A4CAE8000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000C4D6D46C97CF6698DB7AAAE492BFF095C3F28FBFF1
83BAEF63A3E95FA0E863A3EB61A6ED64A7ED66AAEE6CADF171B3F576B8FB
86C2FCB4CED66B8D8E171719000000000000000000000000000000000000
000000000000000000000000000000A1BBD26596D670A2E08DBCF19FCBF7
A2CEF59AC8F589BEF560A4F05CA4F061A6F162A7F264AAF166A8EF68ACF2
6FB1F678B7F981C2FF9ECCEC5F7A7C566C6F526A6B1B1C1F151618000000
000000000000000000000000000000000000D8E8DF89AAD2679BDB79ACE4
97C3F5A4CFF9AED8F8A1CFF97DB9F55BA1F15BA4F05FA6F061A6F364A9F3
67AAF167ABF16EB0F774B5F77EBDFB92CBFC80979A5C75765973745A7676
171719161618000000000000000000000000000000000000D0E1DF7FA6D3
6B9EDD7CAFEB94C3F59ECBF7A1CFF998C9FA74B0F35B9FEF5FA2EC62A5EE
65A7F365A9F565ABF367AAEE6AACF472B4F97CBEFC90CDFF98B4C2597072
576D6F5971733E4C4F1F1E211D1C1F1A1A1E19191B000000000000000000
C9DDDB7DA6D46EA2DE77ABE88ABBEF93C3F291C1F584BAF563A5ED62A7F0
5699E05C9FEC65A5F163A8F262A7F263A7EE69ACF272B5F97FC0FE8DCCFF
93B8CC617B7F54686A4C5C5F4D5F623A46491E1F221D1D201D1D20000000
000000000000CADFDD83A9D474A6DF6EA8E47BB1E984B7EB80B5EE6BA8EC
559CE75D9FE85499E4589EE85CA3EC60A4EE65A6EF65A7EE69ACF372B5F9
80C2FD8BCDFF8CB5CF72929D607A82566B704451544F6264222226212125
2021241E1E22000000000000D4E7E18AAED57AA8E06BA6E36DA7E470A8E7
6CA6E7579BE65097E65A9AE55FA0E75EA1EC5CA0EC60A3ED66A5ED67A6EE
69ACF274B6FA82C4FE8CCCFF88B2CE7CA0B57292A5678392566A744F6267
383F4328282C26262A232327000000000000E2F1E997B7D479A9DF75A8E0
69A4E2629FE25C9BE25296E25898E45D9DE65C9FE85C9FEC5EA0EC62A3ED
67A5F166A9EE6CB0F478BAFA86C7FF88C7FE89B5D182ABC77DA3BE7799B3
6D8CA35C7280434D552E2E332D2E3229292E000000000000000000B2CAD5
7CA8DA7BAAE273A7E562A0E15596DD5395E05495E45A99E65A9BE95C9FE8
5DA1E963A3F068ABF46DADF072B2F57EBFFC88C5FF89C4F696C9DD86B4D3
7EABCC7EA5C5789CB86C89A05A6F7E3B4047323338303035000000000000
000000D6E5E28BAED17AAEE477AAE676A9E869A3E6609BDF5D99E35A99E4
5A9DE75DA1E862A2E76CABF16FAEF470AFF279B8FA81C1FF79B5F6AAE2F3
A6DBE88DC0DF7DADD57BA6CA7DA1C27698B36A859A4C576335353C34353A
000000000000000000000000B3C8CE7DA9D47AB0E978ABE673AAE76CA6E8
69A0E564A0E563A3E766A3E969A6E96FACED71B0F378B7FA7FC0FD79B3ED
8EC9F3B9F1F0ACE3EA94C8E27DAFD979A6CD7BA1C2799BB97291A95D7285
3F454D36373C000000000000000000000000E0F2E89CB2B877A0CB7BB0E5
76AFE874ACEC6FA8E96CA6EB6AA6ED6BA9EC6DACEF74B2F47AB9FC7BB9F3
69A0D982BAE8BFF3F5B9EFEFADE2E794C6DE7DAED775A3CC769CBD779AB7
7494AE677F974D57653A3B40000000000000000000000000010101D3E5DC
9AAAAF7391AF73A1CC74A9E172ADE973ADF076B0F273AFEE71B0EE70A7D6
618AB15480AF78B1DEC0F6F7BEF1F1B3EAEAA7DADF8DBCD67AA8D0739FC7
7397B87595B17392AC6B869D58687A434952000000000000000000000000
0403045A7173B2C8C1ABBDBE7D929E67829660839C6387A75C83A35F89AE
5471883C4B5B4C6E9B8EC8E6BAF0F3BBEFF0B4EAE9ABDEE099C8D583AECE
75A2CA6F98BF6F91B27190AA708DA76C87A05F7487515C6B000000000000
000000000000030303586F71617E805E787AA2B7B696A8AB717F825B6669
5159654F5E6C4E5F756992BE97CEE3A6D9E2ABE0E5AADEE3A2D4DB96C4D4
85B0CC78A2C8719BC56B92BA6C8EB06E8BA76F8BA56A849D647A90657D93
0000000000000000000000000000002323273D4C4F638182546B71607987
56697645597049668F516F996284A8739EBD7DABC78AB8CE93C3D393C1D0
8CB7CB82ACC47AA2C2739AC06B91BA698EB46A8BAC6D89A56E89A26C87A0
69839B7291AD0000000000000000000000000000001C1C1F212125495D5E
3A484E44545E4A5A664C5F74526A895E7B9B6B8DAF6D91AF6A90AE7198B5
78A0BA7AA1BB789EB97297B46B8FB16688AC6688AC6686A766819E677F96
677F966881986F8BA67FA6C600000000000000000000000000000018181B
22222618191B18191B2B3138353D443E485347525F576674607487596E85
5268825A7490607C9763809D617C995F79955D76925F7894607A97617994
5E71865B687A55627161768A7CA1C18CBAE0000000000000000000000000
00000000000025252918181A1516181D1D1F21212533384035383F34343A
39393E3D3E4444465049505D4B55664D586A4D56654F5766515D6D566477
576779576578545F6E505B674E576353616F779AB88CBAE0000000000000
00000000000000000000000000000000000012121319191C1E1E20353C44
3A404831313637383D3C3C4240404744444B46474E48485047485047484F
4B505A525C695A697A5B6C7C5563723D3E44464C565565758CBAE08CBAE0
000000000000000000000000000000000000000000000000000000141517
1B1C1E1F1F22404B542D2D3333343938383E3B3B423F404642434A44454C
45464D45464E525A6644454C5561703F3F463D3D443B3B424D596761798F
8CBAE08CBAE0000000000000000000000000000000000000000000000000
0000000000001314164E64684F636854676F566972556873566775515E6A
535F6C607585617585698295708DA47493AE657D93657C92647B9162798F
60778D000000000000000000
} #{
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFB5
755A335772B2FDFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFA9
24000000000000001EA0
FFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFF7
5A000000000000000000
000054F4FFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFF
FD450000000000000000
00000000003CFAFFFFFF
FFFFFFFFFFFFFFFFFFFF
FFFF7200000000000000
000000000000000069FF
FFFFFFFFFFFFFFFFFFFF
FFFFFFDC030000000000
00000000000000000000
03CBFCFFFFFFFFFFFFFF
FFFFFFFFFF6600000000
00000000000000000000
00000053F6FAFDFFFFFF
FFFFFFFFFFFFFD120000
00000000000000000000
000000000008E9F5F8FB
FEFFFFFFFFFFFFFFD600
00000000000000000000
0000000000000000C1EE
F1F5FBFEFEFFFFFFFFFF
B8000000000000000000
00000000000000000000
9EE4ECF0F5FAFCFEFFFF
FFFFB500000000000000
00000000000000000000
00008ACEDAE7F0F5FAFC
FDFFFFFFD00000000000
00000000000000000000
0000000077A2B4CEE4EE
F7FBFDFFFFFFF7090000
00000000000000000000
0000000000015D7187A5
C7E0EFF9FCFEFFFFFF4E
00000000000000000000
000000000000000B384B
5C769FC2E1F3F8FCFFFF
FFC10000000000000000
00000000000000000012
223041587AA2CAE7F3FB
FFFFFFFF4E0000000000
00000000000000000000
04151F2C3B4D6886AFD6
EBF8FFFFFFFFEE230000
00000000000000000000
00010F162232404F687E
9DC5E5F6FFFFFFFFFFDE
2C000000000000000000
0000020D131E2E3E4A5B
71879FBFE0F6FFFFFFFF
FFFDED65060000000000
0000010C1719202E414D
57667C90A7C4E4F8FFFF
FFFFFFFDF9F6D2733110
00060E273B3731313B48
565E6977889FB5CEE9FA
FFFFFFFFFFFEFBF7F3EA
D4BA90645059625A5554
5B666D75838D9CB1C3D7
ECFAFFFFFFFFFFFEFDF9
F7F3EADBC4A38988918B
8281848A929AA2AAB7C6
D5E2F0FAFFFFFFFFFFFF
FDFBFAF7F3EFE6D7CAC9
C8BFB4B4B5B9BFC2C7CF
D6DDE7EEF6FCFFFFFFFF
FFFFFFFDFBF9F9F6F4F2
EEEBE5E1DEDCDDDEE2E6
E8EBEFEDF1F9FCFDFFFF
FFFFFFFFFFFFFEFBFBF9
F8F9F6F3F1F0EFEEEEF0
F3F5F6F7F9F8F8FDFEFF
FFFFFFFFFFFFFFFFFFFF
FDFCFBFDFCFAF9F8F8F9
F8FAFAFDFCFDFDFDFCFE
FFFFFFFFFFFFFFFFFFFF
FFFFFFFDFDFDFDFDFDFC
FCFBFBFAFBFDFEFEFEFE
FEFFFFFF
}]
		
	;-    collection:
	;
	; this contains all the current icon sets being used.
	;
	; structure: 
	;
	;     collection: [ set [ icon-name plug!  icon-name plug!  ... ] set [...] ... [
	;
	collection: []
	
	
	;-  
	;- FUNCTIONS
	;-
	;-----------------
	;-    channel-copy()
	;-----------------
	channel-copy: func [
		raster [image!]
		from [word!]
		to [word!]
		/into d
		/local pixel i b p 
	][	
		b: to-binary raster
		
		d: to-binary any [d raster]
		
		from: switch from [
			red r [3]
			green g [2]
			blue b [1]
			alpha a [4]
		]
	
		to: switch to [
			red r [3]
			green g [2]
			blue b [1]
			alpha a [4]
		]
	
		either (xor from to) > 4 [
			; when going to/from alpha we need to switch the value (rebol uses transparency not opacity)
			repeat i to-integer (length? raster)  [
				p: i - 1 * 4
				poke d p + to to-char (255 - pick b p + from)
			]
		][
			repeat i to-integer (length? raster)  [
				p: i - 1 * 4
				poke d p + to to-char pick b p + from
			]
		]
		d: to-image d
		d/size: raster/size
		d
	]
	
	
	;-----------------
	;-    parse-set-folder()
	;
	; given a path to a folder, return a block structure which lists all the available icons in the set.
	; 
	; the parser ignores all files except for .png and .iconset files.
	; 
	; the iconset files are opened, and may be decompressed if a special flag within the header.
	;
	; <TO DO>
	;	-support .iconset files
	;   -support compression (optional) in .iconset files
	;   -support system icons via routines.
	;-----------------
	parse-set-folder: func [
		path [file!]
		/local item list icons ext size digit digits to name name-end blk
	][
		vin [{parse-set-folder()}]
		
		icons: copy []
		list: sort read path
		
		digit: charset "0123456789"
		digits: [some digit]
		
		
		foreach item list [
			;probe item
			
			parse item [
				name:
				some [
					name-end: "-" size: digits to:".png" end (
						;print ["found an icon" copy/part name name-end "of size:" copy/part size to]
						name: copy/part name name-end
						either blk: select icons name [
							append blk to-integer copy/part size find size "."
						][
							append icons name
							append/only icons reduce [to-integer copy/part size find size "."]
						]
					)
					| skip
				] 
			]
		]
		
		vout
		
		icons
	]
	
	
	;-----------------
	;-    safe-icon-name()
	;-----------------
	safe-icon-name: func [
		name [string! word!]
		/local new
	][
		;vin [{safe-icon-name()}]
		new: either string? name [
			to-word replace/all name " " "-"
		][
			name
		]
		;vout
		new
	]
	
	
	
	
	;-----------------
	;-     load-icons()
	;
	; <TO DO> fallback image handling
	;-----------------
	load-icons: func [
		/set set-name [word!] "the name of the icon set to load"
		/style name [word!] "use a different style than the default look for this set."
		/size width [integer!] "specify a different size than the default"
		/only icons [word! block!] "only load the given icons, not the whole set"
		/as new-set-name [word!] "changes the name when storing a loaded set into the icon collection, so you can two sets with different-scaling or style in ram"
		/path folder [file!] "the root folder in which to find the icon sets. It MUST contain a folder called default or else, you will have to be very carefull in refering to all sets by name..."
		/local icon sizes img plug rgb alpha blk
	][
		vin [{load-icons()}]
		; normalize parameters
		style: any [name default-style]
		width: any [width default-size]
		set-name: any [set-name default-set]
		folder: any [folder  rejoin [root-path "icons/" set-name "/" style "/"]]
		
		; make sure the icon set really exists
		either dir? folder [
			set-name: any [new-set-name set-name]
			; reuse or create a set
			set: any [
				select collection set-name
				last append collection reduce [set-name copy []]
			]
		
			; load image files and dump them in container plugs
			blk: parse-set-folder folder
			
			foreach [icon sizes] blk [
				either find sizes width [
					; load the icon directly
					img: load rejoin [folder icon "-" width ".png"]
				][
					; missing icon size.
					; load the largest icon and resize it (keeping its alpha!).
					;probe "didn't find an appropriate icon"
					
					img: load rejoin [folder icon "-" last sizes ".png"]
					alpha: channel-copy img 'alpha 'red
					
					img: draw width * 1x1 compose [image img 0x0 (width * 1x1)]
					alpha: draw width * 1x1 compose [image alpha 0x0 (width * 1x1)]
					img: channel-copy/into alpha 'red 'alpha img
				]
				
				
				; do we replace or add a new icon
				either plug: select set safe-icon-name icon [
					;probe "REPLACING ICON"
					fill* plug img
				][
					append set reduce [ safe-icon-name icon   liquify*/fill !plug img ]
				]
					
			]
		][
			to-error rejoin ["icons/load-icons(): required set doesn't exist at " folder]
		]
		vout
	]
	
	
	;-----------------
	;-     icon-label()
	;-----------------
	icon-label: func [
		name [word! string! issue!]
	][
		vin [{icon-label()}]
		name: to-string name
		
		;print "icon label!"
		;probe name
		
		replace/all name "_" " "
		
		vout
		name
	]
	
	
	
	;-----------------
	;-     get-icon()
	;
	; we attempt to get an image from the collection.
	;
	; if it doesn't exist, we return a fallback icon (a blue marble) 
	;-----------------
	get-icon: func [
		name [word!]
		/set set-name
		/image "returns the image, not the plug, of the icon"
		/local plug icon
	][
		vin [{get-icon()}]
				
		;probe extract collection 2
		set: select collection any [set-name default-set]
		
		
		plug: any [
			select set name
			select set *fallback
		]
		icon: either image [
			content* plug
		][
			plug
		] 		
		
		
		vout
		icon
	]
	
	
	
	
]

;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %icons.r 
    date: 14-Jan-2010 
    version: 0.1.0 
    slim-name: 'icons 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: ICONS
;--------------------------------------------------------------------------------




;-  
;- ----------- 
;--------------------------------------------------------------------------------
;- ---> START: STYLE-IMAGE  v0.5.3
;--------------------------------------------------------------------------------

append slim/linked-libs 'style-image
append/only slim/linked-libs [


;--------
;-   MODULE CODE



;- slim/register/header
slim/register/header [
	; declare words so they stay bound locally to this module

	layout*: get in system/words 'layout
	
	

	;- LIBS
	to-color: none
	
	!glob: none
	glob-lib: slim/open/expose 'glob none [!glob to-color]
	
	marble-lib: slim/open 'marble none
	event-lib: slim/open 'event none
	
	!plug: liquify*: content*: fill*: link*: unlink*: none
	liquid-lib: slim/open/expose 'liquid none [
		!plug 
		[liquify* liquify ] 
		[content* content] 
		[fill* fill] 
		[link* link] 
		[unlink* unlink] 
		[dirty* dirty]
	]
	
	
	prim-bevel: prim-x: prim-label: prim-knob: none
	master-stylesheet: alloc-marble: regroup-specification: list-stylesheet: collect-style: relative-marble?: none
	top-half: bottom-half: none
	sillica-lib: slim/open/expose 'sillica none [
		master-stylesheet
		alloc-marble 
		regroup-specification 
		list-stylesheet 
		collect-style 
		relative-marble?
		prim-bevel
		prim-x
		prim-label
		prim-knob
		top-half
		bottom-half
	]
	epoxy-lib: slim/open/expose 'epoxy none [!box-intersection]

	

	;--------------------------------------------------------
	;-   
	;- GLOBALS
	;

	;--------------------------------------------------------
	;-   
	;- !IMAGE[ ]
	!image: make marble-lib/!marble [
	
		;-    Aspects[ ]
		aspects: make aspects [
			;-    size:
			size: 200x200
			
			
			;-        image:
			; contains the image to show.
			image: draw 300x300 compose [fill-pen (gold * .8) box 0x0 300x300 fill-pen red line-pattern 5 5 pen white black circle 49x49 30]
			
			
			;-        label:
			; you may add a label below the image (overlayed)
			label: "image"
			

			;-        label-color:
			label-color: white
			
			
			;-        label-shadow-color:
			; a second label printed at 1x1 pixel offset will use this
			; color if its not none.
			label-shadow-color: black
			
			
			;-        font
			font: theme-label-font
			
			;-        padding
			padding: 0x0
			
			;-        align:
			; not yet implemented, but will be used to place the image when using keep-aspect? and the image can "float" within
			; the space its given.
			align: 'center
			
			;-        text-align:
			; aligned from edge of marble, not edge of image.  this allows you to use padding in order to put text underneath.
			; when combined with align, you will be able to have full control over image location and text.
			text-align: 'bottom
			
			
			;-        keep-aspect?:
			keep-aspect?: false
			
			
			
			;-        border-size:
			border-size: 3
			
			;-        border-style:
			; can only be a color for now
			border-style: theme-border-color
			
			;-        corner:
			corner: 4
		]

		
		;-    Material[]
		material: make material [
		
			;-    fill-weight:
			fill-weight: 1x1
			
		]
		
		
		
		
		
		
		
		;-    valve[ ]
		valve: make valve [
		
			type: '!marble
		
			;-        style-name:
			; used as a label for debugging and node browsing.
			style-name: 'image  
			
			
			;-        label-font:
			; font used by the gel.
			;label-font: theme-knob-font
			
			;-        glob-class:
			; defines the glob which will be built by each marble instance.
			;   glob-class/marble  is added automatically by setup.
			glob-class: make !glob [
				pos: none
				
				valve: make valve [
					;-            glob/input-spec:
					input-spec: [
						; list of inputs to generate automatically on setup these will be stored within glob/input
						position !pair (random 200x200)
						dimension !pair (100x30)
						image !any
						label-color !color  (random white)
						label-shadow-color
						label !string ("")
						align !word
						text-align !word
						padding !pair
						font !any
						corner !integer
						border-style !any
						border-size !integer
					]
					
					;-            glob/gel-spec:
					; different AGG draw blocks to use, one per layer.
					; these are bound and composed relative to the input being sent to glob at process-time.
					gel-spec: [
						; event backplane
						position dimension 
						[
							; images are input neutral
						]
						
						; bg layer (ex: shadows, textures)
						; keep in mind... this can be switched off for greater performance
						;[]
						
						; fg layer
						position dimension image label-color label-shadow-color label align text-align padding font corner border-style border-size
						[
							;pen (data/border-style=)
							pen none
							fill-pen none
							image (data/image=) (data/position= + data/padding=) (data/dimension= - 1x1 + data/position=  - data/padding= ) 
							fill-pen none
							pen (data/border-style=)
							line-width (data/border-size=)
							box (data/position= + data/padding=) (data/dimension= - 1x1 + data/position= - data/padding= )(data/corner=)
							pen none
							
;							(prim-label data/label= (data/position= + data/padding=) (data/dimension=   - data/padding= - data/padding= ) 
;							            data/label-shadow-color= data/font= data/text-align=
;							 )
							( if data/label-shadow-color= [	prim-label data/label= data/position= data/dimension= data/label-shadow-color= data/font= data/text-align= ])
							(if data/label-color= [ prim-label data/label= (data/position= - 1x1) data/dimension= data/label-color= data/font= data/text-align= ])
							
						]
						; controls layer
						;[]
						
						; overlay layer
						; like the bg, it may switched off, so don't depend on it.
						;[]
					]
				]
			
			

		
			
			]
			
			;-----------------
			;-        dialect()
			;
			; this uses the exact same interface as specify but is meant for custom marbles to 
			; change the default dialect.
			;
			; note that the default dialect is still executed, so you may want to "undo" what
			; it has done previously.
			;
			;-----------------
			dialect: func [
				marble [object!]
				spec [block!]
				stylesheet [block!] "Required so stylesheet propagates in marbles we create"
				/local data color-count
			][
				vin [{dialect()}]
				color-count: 1
				
				;print "!"
				
				parse spec [
					any [
						set data image! (
							fill* marble/aspects/image data
						)
						
						| set data tuple! (
							switch color-count [
								1 [fill* marble/aspects/label-color data]
								2 [fill* marble/aspects/label-shadow-color data]
								3 [fill* marble/aspects/border-style data]
							]
							color-count: color-count + 1
						)
						
						| 'no-shadow (
							fill* marble/aspects/label-shadow-color none
						)
						
						; we attempt to link to marbles automatically!!!
						| set data object! (
							if all [
								in data 'valve 
								image? content* data
							][
								link*/reset marble/aspects/image data
							]
						)
						
						| set data integer! (
							fill* marble/aspects/corner data
						)
						
						| skip
					]
				]

				vout
			]			
			
		]
	]
]


;--------
;-   SLIM HEADER
[
    title: none 
    author: "Maxim Olivier-Adlhoch" 
    file: %style-image.r 
    date: 25-Jun-2010 
    version: 0.5.3 
    slim-name: 'style-image 
    slim-prefix: none 
    slim-version: 0.9.11 
    slim-requires: none 
    slim-id: none
]]

;--------------------------------------------------------------------------------
;- <--- END: STYLE-IMAGE
;--------------------------------------------------------------------------------






;do %libs/slim.r
slim/open 'glass-libs none

