# dnsapi-route53-python
A dnsapi for [le.sh](https://github.com/Neilpang/le) to update DNS records in AWS Route53 using the AWSCLI python script.

# Prerequisites
The library currently depends on:
* [AWSCLI](https://aws.amazon.com/cli/)
  * Requires Python 2.6.5 or higher.

# Installation
1. Install python and pip
  * For Debian/Ubuntu based systems:
  ```shell
  apt-get install python pip
  ```
2. Install AWSCLI
  ```shell
  pip install awscli
  ```
3. Install [le.sh](https://github.com/Neilpang/le).
4. Run `make install` in this folder to install the library to le.sh's dnsapi folder.

# Usage
To begin, configure AWSCLI with a new profile with the proper permissions to manage the domains you would like to use for Let's Encrypt.
1. For this document, we will use a profile called 'route53'. Use `aws configure --profile route53` to set up the new profile.
2. Enter the access key and secret key of a user that has a Route53 policy. For an example policy, see [this IAM policy](../blob/master/route53-policy.iam).
3. Edit the dns-route53-python.conf file located at `$HOME/.le/dnsapi/` and set the AWS53_PROFILE to 'route53'.

Now use the le.sh command to register a new certificate with the `dns-route53-python` command. For example, to register test.example.com:
```shell
le.sh dns-route53-python test.example.com
```
