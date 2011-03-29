rebol [
	author: "Graham Chiu"
	date: 2011-3-26
	license: 'GPL
    encap: [ title "Synapse HL7 Router v1.0.1 " quiet secure none]
]

#include %/c/rebol-sdk-276/source/prot.r
#include %/c/rebol-sdk-276/source/view.r
#include %/c/rebol-sdk-276/source/viewtop/prefs.r

#include %prot-http.r
#include %xml-parse.r
#include %xml-object.r
#include %s3-ctx.r

;------------
; open libraries used directly in the script
;------------
; do %../libs/slim.r

#include %glass-package.r
gl: slim/open 'glass none


;------------
; /expose allows us to dump some of the functions from the liquid library within our script.
; slim doesn't pollute the global name space on its own.
;------------
slim/open/expose 'liquid none [content link fill]

homedir: what-dir

set-status: func [txt] [
	fill statusfld/aspects/label copy txt
	; print txt
	wait .1
]

wait-poll-period: func [txt /local waittime] [
	if error? try [
		waittime: to-integer txt
		for i waittime 1 -1 [
			set-status rejoin ["waiting " i " mins"]
			wait 0:01
		]
	] [
		for i 5 1 -1 [
			set-status rejoin ["waiting " i " mins"]
			wait 0:01
		]
	]
]

count-outbox: func [  accesskey secretkey edi-id s3root
	/local result errorresult obj contents filename filedata fullpath url
][
	set-status "reading outbox"
	result: to-string Get-s3object/list rejoin [http:// s3root ".s3.amazonaws.com?prefix=" edi-id "%2fout%2f&max-keys=" 1000] accesskey secretkey
	; ?? result
	either parse result [thru {<Error><Code>} copy errorresult to </Code> to end] [
		set-status errorresult
		if parse result [thru <StringToSignBytes> copy errorresult to </StringToSignBytes> to end] [
			errorresult: parse errorresult none
			probe errorresult
		]
	] [
		; print "no error"
		; probe result
		obj: first reduce xml-to-object copy/deep parse-xml+ result
		; probe obj
		if error? set/any 'errorresult try [
			contents: obj/ListBucketResult/Contents
			fill outboxfld/aspects/label 
			either block? contents [
				join form -1 + length? contents " files"
			][ "0 files" ]
		] [
			set-status "Error occurred during directory listing of outbox"
			probe mold disarm errorresult
		]
	]
]

process-receive-dir: func [recvdir accesskey secretkey edi-id s3root
	/local result errorresult obj contents filename filedata fullpath url
] [
	if error? try [
		recvdir: to-rebol-file to-file recvdir
	] [set-status "read directory error!" return]
	if not exists? recvdir [set-status "receive directory does not exist" return]
	; check to make sure all the parameters exist
	foreach param reduce [
		accesskey secretkey edi-id s3root
	] [
		if empty? param [
			set-status "missing required parameter"
			return
		]
	]
	; now read our inbox http://hl7users.s3.amazonaws.com/gramchiu/in/
	result: to-string Get-s3object/list rejoin [http:// s3root ".s3.amazonaws.com?prefix=" edi-id "%2fin%2f&max-keys=" 1000] accesskey secretkey
	either parse result [thru {<Error><Code>} copy errorresult to </Code> to end] [
		set-status errorresult
		if parse result [thru <StringToSignBytes> copy errorresult to </StringToSignBytes> to end] [
			errorresult: parse errorresult none
			probe errorresult
		]
	] [
		; print "no error"
		; probe result
		obj: first reduce xml-to-object copy/deep parse-xml+ result
		; probe obj
		if error? set/any 'errorresult try [
			contents: obj/ListBucketResult/Contents
			; go thru each file skipping the bucket name
			if block? contents [
			foreach fObj next contents [
				; grab the file and then delete
				fullpath: fObj/Key/value?
				set-status join "downloading " filename: last split-path to-file fullpath

				; http://hl7users.s3.amazonaws.com/gramchiu/in/00D34F414A7ABD1C239BB08171AA4407.hl7
				if filedata: Get-s3object url: rejoin [https:// s3root ".s3.amazonaws.com/" fullpath] accesskey secretkey [
					write join recvdir filename filedata
					; now delete the file from S3
					;trace/net on
					result: Delete-s3object url accesskey secretkey
					; ?? result
					if parse result [ thru {<Error><Code>} copy errorresult to </error> to end ][
						set-status rejoin [ errorresult " on " filename ]
					]
					;trace/net off
				]
			]
			]
		] [
			set-status "Error occurred during file downloads"
			probe mold disarm errorresult
		]
	]
]

process-send-dir: func [sourcedir accesskey secretkey edi-id s3root
	/local msh result errorresult archivedir
] [
	; parse all the sourcedir files and send if the sourceid is the same as the edi-id, and the destinationid is not the edi-id
	if error? try [
		sourcedir: to-rebol-file to-file sourcedir
	] [set-status "source directory error!" return]
	if not exists? sourcedir [set-status "source directory does not exist" return]
	; create the archive directory
	if not exists? archivedir: join sourcedir %archive/ [
		if error? try [
			make-dir archivedir
		][
			set-status join "Can't create directory " archivedir
			return
		]
	]
	; check to make sure all the parameters exist
	foreach param reduce [
		accesskey secretkey edi-id s3root
	] [
		if empty? param [
			set-status "missing required parameter"
			return
		]
	]
	; now process each file
	; ?? sourcedir
	foreach file read sourcedir [
		set-status join "reading " file
		if not #"/" = last file [
			; get the first line past the datetime
			msh: read/part join sourcedir file 1024
			msh: parse/all msh "|"
			; check that msh-4 and msh-6 are correct
			either all [msh/4 = edi-id msh/6 <> edi-id] [
				; okay, send this file
				set-status join "sending " file
				; https://hl7users.s3.amazonaws.com/gramchiu/out/00D34F414A7ABD1C239BB08171AA4407.hl7
				; Put-s3object func [url [url!] file [file!] accesskey secretkey
				result: put-S3object rejoin [https:// s3root ".s3.amazonaws.com/" edi-id "/out/" file] join sourcedir file accesskey secretkey
				either empty? result [
					set-status "Uploaded OK"
					if error? try [
						write join archivedir file read join sourcedir file
						delete join sourcedir file
					][
						set-status "Error on moving files - check permissions"
						return
					]
				] [
					either parse result [thru "<Error><Code>" copy errorresult to </Code> to end] [
						set-status errorresult
					] [set-status "Unknown error"]
				]
			][ set-status join "rejected " file ]
		]
	]
	set-status "finished with send directory"
]

;------------
; note that GLASS doesn't directly support words in its dialect
; which is why we compose the layout first, in order to resolve 
; both colors below.
;
; this is a philosophical design decision which may change.
; in fact, I may add paren support to mean that they should be 
; reduced directly.
;------------
gui: gl/layout compose/deep [
	col: column with [spacing-on-collect: 10x10] [
		row 10x10 [
			lbl: auto-title "HL7 Router"
		]
		vframe [
			vcavity [
				subtitle left stiff "Access Key"
				accessfld: field "enter your access key"
			]
			vcavity [
				subtitle left stiff "Secret Key"
				secretfld: field "enter your secret key"
			]
		]
		vframe [
			row [
				column [
					vcavity [
					subtitle left stiff "Send Directory"
					sendfld: field ""
					]
				]
				column [
					vcavity [
					subtitle left stiff "S3 Outbox"
					outboxfld: field "?"
					]
				]
			]
			vcavity [
				subtitle left stiff "Receive Directory"
				receivefld: field ""
			]

			vcavity [
				row [
					column [
						subtitle left stiff "EDI ID"
						ediidfld: field ""
					]
					column [
						subtitle left stiff "Root"
						rootfld: field "hl7users"
					]
					column [
						subtitle left stiff "Polling (Mins)"
						pollfld: field "5"
					]
				]
			]
		]
		vcavity [
			subtitle left stiff "Status"
			statusfld: field "ready"
		]

		row [
			button "Save" 0.0.0 0.255.0 [
				config: make object! [
					access: content accessfld/aspects/label
					secret: content secretfld/aspects/label
					receive: content receivefld/aspects/label
					send: content sendfld/aspects/label
					poll: content pollfld/aspects/label
					edi: content ediidfld/aspects/label
					root: content rootfld/aspects/label
				]
				save/all %hl7router.config config
				set-status "config saved!"
			]
			button "Go" 0.0.0 0.255.0 [
				; process send directory
				; trace/net on
				forever [
					process-send-dir  
						content sendfld/aspects/label
						content accessfld/aspects/label
						content secretfld/aspects/label
						content ediidfld/aspects/label
						content rootfld/aspects/label

					process-receive-dir
						content receivefld/aspects/label
						content accessfld/aspects/label
						content secretfld/aspects/label
						content ediidfld/aspects/label
						content rootfld/aspects/label
					
					count-outbox content accessfld/aspects/label content secretfld/aspects/label content ediidfld/aspects/label content rootfld/aspects/label

					wait-poll-period content pollfld/aspects/label
				]
			]
			button "Quit" 255.255.255 255.0.0 [quit]

		]
	]
]

either exists? %hl7router.config [
	config: load %hl7router.config
	attempt [
		fill accessfld/aspects/label config/access
		fill secretfld/aspects/label config/secret
		fill receivefld/aspects/label config/receive
		fill sendfld/aspects/label config/send
		fill pollfld/aspects/label config/poll
		fill ediidfld/aspects/label config/edi
		fill rootfld/aspects/label config/root
	]
] [
	fill statusfld/aspects/label "Need configuring"
]


do-events
