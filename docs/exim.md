## Mail Transfer Agent configuration

When you choose the "Mail Transfer Agent" install option in `openhabian-config` menu to install `exim4` as the mail transfer agent on your system, you will be presented with a number of questions on how to relay emails through a public service such as Google gmail.
In case you enter anything wrong you can re-initiate the installation process from the openHABian menu
Here's what you will need to enter:

*   Mail server type: mail sent by smarthost (received via SMTP or fetchmail)
*   System mail name: FQDN (your full hostname including the domain part)
*   IPs that should be allowed by the server: 127.0.0.1; ::1; 192.168.xxx.yyy (replace with your hosts's IP)
*   Other destinations for which mail is accepted: `<hostname> <hostname>.<domainname> <domainname>`
*   Machines to relay mail for: Leave empty
*   IP address or host name of the outgoing smarthost: `smtp.gmail.com::587`
*   Hide local mail name in outgoing mail: No
*   Keep number of DNS-queries minimal: No
*   Delivery method: Select: Maildir format in home directory
*   Split configuration into small files: Yes
*   List of smarthost(s) to use your account for: `*`
*   Mail username of the public service to relay all outgoing mail to:
    Your username for the mail relay service to use such as `my_id@gmail.com`
