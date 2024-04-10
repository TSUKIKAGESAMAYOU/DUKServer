#!/usr/bin/perl

my $html='<!DOCFILE html>
<html>
  <title>Welcome to Group 1!</title>
  <header>
    <fieldset>
      <img id="titlejpg" src="../pictureformain/0.jpg" onclick="cPicture()" alt="Group1"/>
    </fieldset>
  </header>

  <body>
    <p>Time: '.localtime.'</p>
  </body>
    <a href="/">Back to title</a>
  <br/>

  <footer align="center">
    <HR width="98%" color=#555 SIZE=1/>
    <big>This Webside is made by G1&#169;.</big>
  </footer>

<link rel="stylesheet" type="text/css" href="../CSS-list/auto.css"/>
</html>';
$html=~s/>\s+</></g;
print $html;