Rebol [
	file: %hl7-router-server.r
	date: 28-Mar-2011
	author: "Graham Chiu"
	rights: 'GPL
	copyright: "Graham Chiu"
	notes: {
		server will read the root directory to get all the folders, and then scan each folder's outbox, and transfer files to the recipients's inbox
		if the recipient does not exist, we can send a ack reject - and delete the message
	}
]

; these are your keys given to you by Amazon
accesskey: "your master access key"
secretkey: "your secret key"
s3root: "hl7users"
waitperiod: 0:05 ; 5 mins
rooturl: rejoin [ http:// s3root ".s3.amazonaws.com/" ]

calcMD5: func [ binData ] [
	return enbase/base checksum/method binData 'md5 16
]

do %prot-http.r
do %xml-parse.r
do %xml-object.r
do %s3-ctx.r

set-status: func [ txt ][
	print txt
]

;; main loop starts here
;	result: to-string Get-s3object/list rejoin [http:// s3root ".s3.amazonaws.com?max-keys=" 1000] accesskey "secretkey"



forever [
	; read the directory of folders and build a list of them - ideally, but we are just going to keep a list of them
	; users: copy []
	; contains a list of all the users
	if error? try [
		users: load %users.r
	][
		users: ["gramchiu"]
	]
	probe users
	; result: read rooturl
	comment {	
	either parse result [thru {<Error><Code>} copy errorresult to </Code> to end] [
		set-status errorresult
		if parse result [thru <StringToSignBytes> copy errorresult to </StringToSignBytes> to end] [
			; errorresult: parse errorresult none
			set-status errorresult
		]
	] [
		obj: first reduce xml-to-object copy/deep parse-xml+ result
		probe obj
	]
}
	foreach edi-id users [
		set-status join "processing " edi-id
		; read each users outbox, and transfer to target users' inbox
		; http://hl7users.s3.amazonaws.com/gramchiu/out/
		result: to-string Get-s3object/list rejoin [https:// s3root ".s3.amazonaws.com?prefix=" edi-id "%2fout%2f&max-keys=" 1000] accesskey secretkey
		either parse result [thru {<Error><Code>} copy errorresult to </Code> to end] [
			set-status errorresult
			if parse result [thru <StringToSignBytes> copy errorresult to </StringToSignBytes> to end] [
				errorresult: parse errorresult none
				probe errorresult
			]
		] [
			; print "no error"
			; - no error on getting the users' outbox, so let's read each file
			obj: first reduce xml-to-object copy/deep parse-xml+ result
			; probe obj
			if error? set/any 'errorresult try [
				contents: obj/ListBucketResult/Contents
				; go thru each file skipping the bucket name
				if block? contents [
					; only do this if there are some files in the outbox
					; so skip the details on the folder itself
					foreach fObj next contents [
						; grab the file and then delete
						fullpath: fObj/Key/value?
						set-status join "downloading " filename: last split-path to-file fullpath
						if filedata: Get-s3object url: rejoin [https:// s3root ".s3.amazonaws.com/" fullpath] accesskey secretkey [
							set-status "file downloaded into ram"
							; we got the file, now parse it to see who it belongs to
							msh: parse/all copy/part filedata 1025 "|"
							print [ "from: " msh/4 ]
							print [ "to: " msh/6 ]
							originator: none
							if msh/4 [
								originator: first parse/all msh/4 "^^"
								replace/all originator " " "_"
							]
							destination: none
							if msh/6 [
								destination: first parse/all msh/6 "^^"
								replace/all destination " " "_"
							]
							; msh/4 - is the originator
							; msh/6 - is the destination
							; make sure that the originator is who they say they are, and that the destination address exists
							case [
								originator <> edi-id [ ; do nothing since this is an impersonation
									print "impersonation"
								]
								
								all [ originator not find users originator ] [
									; there is an addressee, but not present in our list of users
									; so do nothing
									print "addressee not current user"
								]
								none? destination [
									print "no destination"
								]
								none? originator [
									; no addressee - do nothing
									print "no addressee"
								]
								
								all [ originator find users originator ] [
									print "valid from and to addressee"
									; a valid addressee so we need to write to this users' inbox
									addressee: copy originator
									; we have to save this file first :(
									file: to-file calcmd5 filedata
									write file filedata
									result: put-S3object rejoin [https:// s3root ".s3.amazonaws.com/" addressee "/in/" file] file accesskey secretkey
									; it's now written to the users' inbox, so we can now delete our temp file
									delete file
									; now now delete it from the users' outbox
									result: Delete-s3object url accesskey secretkey
								]
								
								true [ ; do nothing
									print "oops .. this case not covered"
								]
							]
						]
					]
				]
			] [
				; we had some error occuring
				; should send out an email
				; or send out a sms
				set-status rejoin ["fault on reading the user " edi-id "'s out bucket"]
			]
		]
	]
	set-status "waiting ..."
	wait waitperiod
]

