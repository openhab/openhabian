## Mail Transfer Agent configuration

When you choose the "Mail Transfer Agent" install option in `openhabian-config` menu to install `exim4` as the mail transfer agent on your system, you will be presented with a number of questions on how to relay emails through a public service such as Google gmail.
In case you enter anything wrong you can re-initiate the installation process from the openHABian menu.

::: tip if you relay via mail.gmail.com or mail.gmx.net
Both of these freemailers will only forward your mail when you authenticate with your Google/GMX username first.
Additionally, GMX requires the "From:" address to be your GMX mail address.
Google allows for arbitrary From: but will override any From: with your Gmail address.

Google meanwhile enforces more strict anti-spamming so authenticating with your standard credentials likely won't work
any more to send mail. But you can generate a static password token for use with applications such as email in your Google account settings.

:::

Here is what you will need to enter:

*   Mail server type: mail sent by smarthost (received via SMTP or fetchmail)
*   System mail name: FQDN (your full hostname including the domain part)
*   IPs that should be allowed by the server: 127.0.0.1; ::1; 192.168.1.100
    (replace the last address with your openHABian server interface IP>)
*   Other destinations for which mail is accepted: `<hostname> <hostname>.<domainname> <domainname>`
*   Machines to relay mail for: Leave empty or 192.168.xxx.0/24 (replace with your local network)
*   IP address or host name of the outgoing smarthost: `smtp.gmail.com::587`
*   Hide local mail name in outgoing mail: No
*   Keep number of DNS-queries minimal: No
*   Delivery method: Select: Maildir format in home directory
*   Split configuration into small files: Yes
*   List of smarthost(s) to use your account for: `*`
*   Mail username of the public service to relay all outgoing mail to:
    Your username for the mail relay service to use such as `my_id@gmail.com`
