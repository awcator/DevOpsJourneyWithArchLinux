### telnet way to send mails
```
[>] means telnet ouput
[<] means my inputs to telnet
[#] my comments, dont give this command

$ telnet smtpdm.aliyun.com 80
[>] Trying 47.89.74.80...
[>] Connected to smtpdm.aliyun.com.
[>] Escape character is '^]'.
[>] 220 smtp.aliyun-inc.com MX AliMail Server(127.0.0.1)
[<] EHLO busybox3
[#] Where busybox3 is myhostname
[>] 250-smtp.aliyun-inc.com
[>] 250-STARTTLS
[>] 250-8BITMIME
[>] 250-AUTH=PLAIN LOGIN XALIOAUTH
[>] 250-AUTH PLAIN LOGIN XALIOAUTH
[>] 250-PIPELINING
[>] 250 DSN
[>] AUTH LOGIN
[>]334 dXNlcm5hbWU6
[#] dXNlcm5hbWU6== stands for username: in base64 enocded. so enter ur username@domain.com in base64 encoded
[<] ZHVtbXl1c2VyQGNkaXAudGVjaA==
[#] echo -n dummyuser@cdip.tech|base64 -w 0  ; gives ZHVtbXl1c2VyQGNkaXAudGVjaA==
[>] 334 UGFzc3dvcmQ6
[#] UGFzc3dvcmQ6: is for password
[<] ZHVtbXlwYXNzd29yZA==
[#]  echo -n dummypassword|base64 -w 0 ; gives ZHVtbXlwYXNzd29yZA==
[>] 235 Authentication successful
[<] MAIL FROM:<dummyuser@cdip.tech>
[>] 250 Mail Ok
[<] RCPT TO:<oivnmblydqzlkfxras@tmmwj.com>
[>] 250 Rcpt Ok
[<] DATA
[#] now strat typing mail body
[>] 354 End data with <CR><LF>.<CR><LF>
[<] Received: by busybox3 (sSMTP sendmail emulation); Sun, 09 Oct 2022 07:52:44 +0000
[<] From: "dummyuser" <dummyuser@cdip.tech>
[<] Date: Sun, 09 Oct 2022 07:52:44 +0000
[<] Subject: This is Subject Line
[<] 
[<] Email content line 1
[<] Email content line 2
[<] .
[#] dot (.) signifies end of body
[>] 250 Data Ok: queued as freedom ###envid=123456789012
[#] Done sending mail , time to quit
[>] quit
[<] 221 Bye
```
