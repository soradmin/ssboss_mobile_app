[0;1;31mUnit postfix.service could not be found.[0m
[0;1;32m●[0m exim4.service - exim Mail Transport Agent
     Loaded: loaded (]8;;file://cv5187376.novalocal/usr/lib/systemd/system/exim4.service/usr/lib/systemd/system/exim4.service]8;;; [0;1;32menabled[0m; preset: [0;1;32menabled[0m)
     Active: [0;1;32mactive (running)[0m since Thu 2025-08-28 09:34:09 MSK; 6 days ago
       Docs: ]8;;man:exim(8)man:exim(8)]8;;
             ]8;;https://exim.org/docs.htmlhttps://exim.org/docs.html]8;;
    Process: 30119 ExecStartPre=/usr/sbin/update-exim4.conf $UPEX4OPTS (code=exited, status=0/SUCCESS)
    Process: 341599 ExecReload=kill -HUP $MAINPID (code=exited, status=0/SUCCESS)
   Main PID: 30362 (exim4)
      Tasks: 3 (limit: 1124)
     Memory: 38.9M (peak: 72.0M)
        CPU: 17min 21.830s
     CGroup: /system.slice/exim4.service
             ├─[0;38;5;245m 30362 /usr/sbin/exim4 -bdf -q30m[0m
             ├─[0;38;5;245m343707 /usr/sbin/exim4 -bdf -q30m[0m
             └─[0;38;5;245m343708 /usr/sbin/exim4 -bdf -q30m[0m

Aug 29 12:41:01 cv5187376.novalocal systemd[1]: Reloading exim4.service - exim Mail Transport Agent...
Aug 29 12:41:01 cv5187376.novalocal systemd[1]: Reloaded exim4.service - exim Mail Transport Agent.
Aug 29 12:41:01 cv5187376.novalocal systemd[1]: Reloading exim4.service - exim Mail Transport Agent...
Aug 29 12:41:01 cv5187376.novalocal systemd[1]: Reloaded exim4.service - exim Mail Transport Agent.
Aug 29 12:42:56 cv5187376.novalocal systemd[1]: Reloading exim4.service - exim Mail Transport Agent...
Aug 29 12:42:56 cv5187376.novalocal systemd[1]: Reloaded exim4.service - exim Mail Transport Agent.
Sep 01 14:59:31 cv5187376.novalocal systemd[1]: Reloading exim4.service - exim Mail Transport Agent...
Sep 01 14:59:31 cv5187376.novalocal systemd[1]: Reloaded exim4.service - exim Mail Transport Agent.
Sep 03 15:24:35 cv5187376.novalocal systemd[1]: Reloading exim4.service - exim Mail Transport Agent...
Sep 03 15:24:35 cv5187376.novalocal systemd[1]: Reloaded exim4.service - exim Mail Transport Agent.

[0;1;32m●[0m dovecot.service - Dovecot IMAP/POP3 email server
     Loaded: loaded (]8;;file://cv5187376.novalocal/usr/lib/systemd/system/dovecot.service/usr/lib/systemd/system/dovecot.service]8;;; [0;1;32menabled[0m; preset: [0;1;32menabled[0m)
     Active: [0;1;32mactive (running)[0m since Thu 2025-08-28 09:34:10 MSK; 6 days ago
       Docs: ]8;;man:dovecot(1)man:dovecot(1)]8;;
             ]8;;https://doc.dovecot.org/https://doc.dovecot.org/]8;;
    Process: 341607 ExecReload=/usr/bin/doveadm reload (code=exited, status=0/SUCCESS)
   Main PID: 30406 (dovecot)
     Status: "[0;1;36mv2.3.21 (47349e2482) running[0m"
      Tasks: 10 (limit: 1124)
     Memory: 13.6M (peak: 24.5M)
        CPU: 2min 27.428s
     CGroup: /system.slice/dovecot.service
             ├─[0;38;5;245m 30406 /usr/sbin/dovecot -F[0m
             ├─[0;38;5;245m 30407 dovecot/anvil[0m
             ├─[0;38;5;245m341609 dovecot/log[0m
             ├─[0;38;5;245m341619 dovecot/auth[0m
             ├─[0;38;5;245m341620 dovecot/stats[0m
             ├─[0;38;5;245m341621 dovecot/config[0m
             ├─[0;38;5;245m343644 dovecot/imap-login[0m
             ├─[0;38;5;245m343645 dovecot/imap-login[0m
             ├─[0;38;5;245m343646 dovecot/imap[0m
             └─[0;38;5;245m343647 dovecot/imap[0m

Sep 03 16:22:16 cv5187376.novalocal dovecot[341609]: pop3-login: Disconnected: Connection closed: SSL_accept() failed: error:0A000412:SSL routines::sslv3 alert bad certificate: SSL alert number 42 (no auth attempts in 1 secs): user=<>, rip=37.98.158.173, lip=192.168.0.231, TLS handshaking: SSL_accept() failed: error:0A000412:SSL routines::sslv3 alert bad certificate: SSL alert number 42, session=<FGxMfuU9CAklYp6t>
Sep 03 16:22:16 cv5187376.novalocal dovecot[341609]: pop3-login: Disconnected: Connection closed: SSL_accept() failed: error:0A000412:SSL routines::sslv3 alert bad certificate: SSL alert number 42 (no auth attempts in 0 secs): user=<>, rip=37.98.158.173, lip=192.168.0.231, TLS handshaking: SSL_accept() failed: error:0A000412:SSL routines::sslv3 alert bad certificate: SSL alert number 42, session=<XuxNfuU9Fy0lYp6t>
Sep 03 16:22:16 cv5187376.novalocal dovecot[341609]: pop3-login: Disconnected: Aborted login by logging out (no auth attempts in 0 secs): user=<>, rip=37.98.158.173, lip=192.168.0.231, session=</KNSfuU9KgklYp6t>
Sep 03 16:22:16 cv5187376.novalocal dovecot[341609]: pop3-login: Disconnected: Connection closed (no auth attempts in 0 secs): user=<>, rip=37.98.158.173, lip=192.168.0.231, session=<G6RTfuU9EwklYp6t>
Sep 03 16:23:10 cv5187376.novalocal dovecot[341609]: imap-login: Disconnected: Connection closed: SSL_accept() failed: error:0A000412:SSL routines::sslv3 alert bad certificate: SSL alert number 42 (no auth attempts in 1 secs): user=<>, rip=37.98.158.173, lip=192.168.0.231, TLS handshaking: SSL_accept() failed: error:0A000412:SSL routines::sslv3 alert bad certificate: SSL alert number 42, session=<YrqFgeU9Ai0lYp6t>
Sep 03 16:23:40 cv5187376.novalocal dovecot[341609]: imap-login: Disconnected: Connection closed (auth failed, 3 attempts in 14 secs): user=<info>, method=PLAIN, rip=37.98.158.173, lip=192.168.0.231, TLS, session=<eWWDguU9JBclYp6t>
Sep 03 16:23:44 cv5187376.novalocal dovecot[341609]: imap-login: Login: user=<info@ssboss.shop>, method=PLAIN, rip=37.98.158.173, lip=192.168.0.231, mpid=343643, TLS, session=<P1pag+U9MAklYp6t>
Sep 03 16:23:44 cv5187376.novalocal dovecot[341609]: imap(info@ssboss.shop)<343643><P1pag+U9MAklYp6t>: Disconnected: Logged out in=9 out=482 deleted=0 expunged=0 trashed=0 hdr_count=0 hdr_bytes=0 body_count=0 body_bytes=0
Sep 03 16:23:45 cv5187376.novalocal dovecot[341609]: imap-login: Login: user=<info@ssboss.shop>, method=PLAIN, rip=37.98.158.173, lip=192.168.0.231, mpid=343646, TLS, session=<Sbqgg+U9PxclYp6t>
Sep 03 16:23:45 cv5187376.novalocal dovecot[341609]: imap-login: Login: user=<info@ssboss.shop>, method=PLAIN, rip=37.98.158.173, lip=192.168.0.231, mpid=343647, TLS, session=<Lwelg+U9Di0lYp6t>
