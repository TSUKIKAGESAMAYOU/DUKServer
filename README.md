Hello, here is Tsukikage Samayou!
DUK - Dumpling United Kingdom, is a project I created when I was young. It's to show messages about a folk of Children's organization.
At that time, I can only produce simple html pages. About ten years passed, I can continue my work.
By the way, I created a simple server by Perl, for both Perl is simple and it's my second programmming language.

Programming language: Perl v5.10.0+ (Perl interpreter download first)
Encoding: UTF-8
OS: Linux / Windows

# manage.pl
Running programme.
## Echo:
Waiting on 80: Ready, it's able to input Commands.
Asking for 80: Loading failed, it will repeat requesting 1 time per second.
## Command:
s.*: start server.pl
e.*: exit
i.*: Show threads forked(Often error if huge threads died abnormally)
on : Show detailed http packages
b.*: Show brief information like: receivede from ...
off: No echo
clear|reset|cls: reset screen(**Unable on Windows**)
## perldoc
introduction of functions

# server.pm
load only when needed at once.
**It's able to load your own server, with two scalar able: $server::echo_html and &server::server_call**
## Function introduction
### &server_call
  The entry of server. Repeating creating socket.
### &reply
Forked from &server_call, the largest part.
#### Acceptable Header
##### GET
/ : return page in mainpage.ini
files in jump.ini: jump according to jump.ini
###### extendtions:
in interpreter.ini: will be run as a dynamic pages, forked out and return the htmls got from.
in content-type.ini: HTTP header
##### POST
op. cit.
Only dynamic pages acceptable
#### Acceptable Type
200: successful
302: jump by jump.ini
304: require same Etags file
404: not found
405: send POST to a not executable pages
406: return unacceptable type of browser
501: bad request like PUT
### &build_html
organize the %headers from &reply
### &loadfile
enclosure reading a file
## perldoc
introduction of functions

# inis
## content-type.ini
a perl hash like:
  extension name => HTTP Content-Type
nonexistent type but found will send as downloading it
## interpreter.ini
a perl hash like:
  extension name => interpreter(call by bash or DOS ...)
specify the interpreter of dynamic pages, so you can produce your own interpreter to interpret .jsp and so on.
## jump.ini
a perl hash like:
  original page => new page
to guide &server::reply jump
## mainpage.ini
**when get a void, the mainpage.ini specify a default page**
essentially a special jump, **usually corporate with this key-value in jump.ini:**
  '/' => ''
