<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="refresh" content="10">
    <style>
      .button {
      background-color: #4CAF50; /* Green */
      border: none;
      color: white;
      padding: 15px 32px;
      text-align: center;
      text-decoration: none;
      display: block;
      width: 95%;
      font-size: 30px;
      margin: 4px 8px;
      cursor: pointer;
      }
      .button2 {background-color: #008CBA;} /* Blue */
      .button3 {background-color: #f44336;} /* Red */ 
      .button4 {background-color: #e7e7e7; color: black;} /* Gray */ 
      .button5 {background-color: #555555;} /* Black */
    </style>
  </head>
  <body>
    <h1> ESP8266 Web Server
      <br>
      <h2> The Counter: %d
	<br>
	<label for="fuel">Fuel Level:</label>
	<meter class="meter" id="fuel" name="fuel" min="0" max="100" value="%d">
    </meter></h1>
    <form action="" method="get">
      <button type="submit" class="button button3" name="One" value="Empty"> Empty</button>
      <button type="submit" class="button button5" name="Two" value="Off"> Off</button>
      <button type="submit" class="button button2" name="Three" value="Fill"> Fill</button>
    </form>
  </body>
</html>
//create function and execute it immediately
(function doPoll() {
    var oReq = new XMLHttpRequest();
    //set up listener for when server responds
    oReq.addEventListener("load", function() {
    //make the DOM reflect whatever new data we got
    document.getElementById("someID").innerHTML = xhr.responseText;
    //set up the next invocation of the polling loop, 100 is the delay in 
ms
    //(as written this only happens on success so any single failed 
request makes the entire thing stop)
    window.setTimeout(doPoll, 100);
    });
    oReq.open("GET", "http://192.168.1.1");
    //fire the missiles
    oReq.send();
})();
