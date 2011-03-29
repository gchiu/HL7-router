rebol [
	file: %s3-ctx.r
	author: "Graham Chiu"
	date: 28-March-2010
	rights: 'GPL
]


s3-ctx: context [

	collect: func [; a.k.a. gather ?
		[throw]
		{Collects block evaluations.}
		'word "Word to collect (as a set-word! in the block)"
		block [any-block!] "Block to evaluate"
		/into dest [series!] "Where to append results"
		/only "Insert series results as series"
		;/debug
		/local code marker at-marker? marker* mark replace-marker rules
	] [
		block: copy/deep block
		dest: any [dest make block! []]
		; "not only" forces the result to logic!, for use with PICK.
		; insert+tail pays off here over append.
		;code: reduce [pick [insert insert/only] not only 'tail 'dest]
		; FIRST BACK allows pass-thru assignment of value. Speed hit though.
		;code: reduce ['first 'back pick [insert insert/only] not only 'tail 'dest]
		code: compose [first back (pick [insert insert/only] not only) tail dest]
		marker: to set-word! word
		at-marker?: does [mark/1 = marker]
		; We have to use change/part since we want to replace only one
		; item (the marker), but our code is more than one item long.
		replace-marker: does [change/part mark code 1]
		;if debug [probe code probe marker]
		marker*: [mark: set-word! (if at-marker? [replace-marker])]
		parse block rules: [any [marker* | into rules | skip]]
		;if debug [probe block]
		do block
		head :dest
	]

	url-encode: func [
		{URL-encode a string}
		data "String to encode"
		/local normal-char new-data
	] [
		normal-char: charset [
			#"A" - #"Z" #"a" - #"z"
			#"@" #"." #"*" #"-" #"_"
			#"0" - #"9"
		]
		data: form data
		collect/into ch [
			forall data [
				ch: either find normal-char first data [first data] [
					rejoin ["%" to-string skip tail (to-hex to-integer first data) -2]
				]
			]
		] copy ""
	]

	now-gmt: has [t] [
		t: now
		t: t - t/zone
		t/zone: none
		t
	]

	hmac-sha1: func [val key] [checksum/method/key val 'sha1 key]

	make-sig: func [
		{Encodes the given string with the aws_secret_access_key, by taking the
    hmac-sha1 sum, and then base64 encoding it.}
		data [string!]
		secret-key [string!]
		/for-url "Make encoded string usable as a query string parameter"
		/local res
	] [
		res: enbase/base hmac-sha1 data secret-key 64
		either for-url [url-encode res] [res]
	]

	Comment {
StringToSign = HTTP-Verb + "\n" +
	Content-MD5 + "\n" +
	Content-Type + "\n" +
	Date + "\n" +
	CanonicalizedAmzHeaders +
	CanonicalizedResource;

}

	create-string-to-sign: func [verb md5 [none! string!] type url [url!]
		/list {display directory information}
		/local obj bucket resource s
	] [
		obj: make object! [path: target: port-id: host: none]
		net-utils/URL-Parser/parse-url obj url
		;probe obj	
		parse obj/host [copy bucket to ".s3.amazonaws.com"]
		;?? bucket
		; probe obj/target
		; ?? obj
		resource: either list [
			rejoin ["/" url-encode bucket "/" any [obj/path copy ""]]
		] [
			rejoin ["/" url-encode bucket "/" any [obj/path copy ""] either obj/target [url-encode obj/target] [""]]
		]
		; ?? resource
		s: rejoin [verb newline
			any [md5 copy ""] newline
			any [type copy ""] newline
			to-http-date newline
			resource
		]
	]

	to-http-date: func [
		/local d
	] [
		d: now-gmt
		rejoin [
			copy/part pick system/locale/days d/weekday 3
			", " next form 100 + d/day " "
			copy/part pick system/locale/months d/month 3
			" " d/year " "
			next form 100:00 + d/time " +0000"
		]
	]


	data: copy ""
	
	set 'Delete-s3object func [ url accesskey secretkey
		/local  err signature result data
	][
		data: create-string-to-sign "DELETE" none "text/plain" url
		; ?? data
		signature: make-sig data secretkey
		if error? set/any 'err try [
			result: read/custom to-url url compose/deep [
				DELETE ""
				[
					Date: (to-http-date)
					Authorization: (rejoin ["AWS " accesskey ":" signature])
					Content-type: "text/plain"
				]
			]
			return result
		][
			probe mold disarm err
			return false
		]
	]

	set 'Get-s3object func [url [url!] accesskey secretkey
		/async awakefunction [function!]
		/info
		/list
		/local err signature result verb data p content-type
	] [
		verb: either info ['HEAD] ['GET]
		content-type: either list ["plain/text"] ["application/octet-stream"]
		data: either list [create-string-to-sign/list verb none content-type url] [create-string-to-sign verb none content-type url]

		signature: make-sig data secretkey
		if error? set/any 'err try [
			either async [
				; url is like this http://a-browsertests.s3.amazonaws.com/makepdf.rsp or https://a-browsertests.s3.amazonaws.com/makepdf.rsp
				; and we want to change it to ahttp or ahttps
				insert head url 'a

				p: open/custom to-url url compose/deep [
					(verb) "" header
					[
						Date: (to-http-date)
						Authorization: (rejoin ["AWS " accesskey ":" signature])
						Pragma: "no-cache"
						Cache-Control: "no-cache"
					]
				]
				p/awake: :awakefunction
				wait []
			] [
				result: read/custom/binary to-url url compose/deep [
					(verb) ""
					[
						Date: (to-http-date)
						Authorization: (rejoin ["AWS " accesskey ":" signature])
						; Pragma: "no-cache"
						; Cache-Control: "no-cache"
						Content-type: (content-type)
					]
				]
				return result
			]
		] [
			; probe mold disarm err
			return none
		]
	]

	set 'Put-s3object func [url [url!] file [file!] accesskey secretkey
		/local err signature result content-type
	] [
		content-type: form switch/default suffix? file [
			%.html ['text/html]
			%.jpg ['image/jpeg]
			%.jpeg ['image/jpeg]
			%.png ['image/png]
			%.tiff ['image/tiff]
			%.tif ['image/tiff]
			%.pdf ['application/pdf]
			%.txt ['text/plain]
			%.xml ['application/xml]
			%.mpeg ['video/mpeg]
			*.hl7 ['text/plain]
		] ['application/octet-stream]

		data: create-string-to-sign "PUT" none content-type url
		signature: make-sig data secretkey
		if error? set/any 'err try [
			result: read/custom url reduce compose/deep [
				'PUT file
				[
					Date: (to-http-date)
					Authorization: (rejoin ["AWS " accesskey ":" signature])
					Content-type: (content-type)
				]
			]
			; ?? result			
			return result
		] [
			;probe mold disarm err
			return mold disarm err
		]
	]
]