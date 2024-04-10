function cPicture(){
  if(i<25)
    ++i;
  else i=0;
  s.src=autobegin+i.toString()+autoend;
}
function clickIndex(){
  document.getElementById("pChange").innerHTML+=document.getElementById("InputBox1").value;
}
function clickClear(){
  document.getElementById("pChange").innerHTML="";
}
function clickEline(){
  document.getElementById("pChange").innerHTML+="<br/>";
}