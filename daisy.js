var Ttime=0;
var Utime;
var timeOutID=null;
var nTimeOut=0;
var pollAwake = false;
const pollLoopTime=2000;
const fastTimeOut=3*pollLoopTime;
const slowTimeOut=6*fastTimeOut;
var smoothie;
var smoothieLine1;
var smoothieLine2;
var smoothieLine3;
var smoothieLine4;
var smoothieLine5;
var smoothieLine6;
var smoothieLine7;
var smoothieLine8;
var smoothieLine9;
var timeOutAwake=true;
//
var ipAddr = location.host;
//
//testing
//var ipAddr=""
//var ipAddr="localhost:5000"
//var ipAddr="10.0.0.48:5000"
//

console.log("ipAddr: " + ipAddr)

$(document).ready(function() {
    console.log("ready fcn")
    smoothieSetup();
    G123Setup();
});
//
function pollCB() {
    var channelValues = JSON.parse(oReq.responseText);
    var ii = 0;
    var G1;
    var selCh, pf, plsScl, ustr, estr;
    var cn, cv, cu;
    var sl;
    var Utime=new Date();
    for (ch in channelValues) {
	ii = ii + 1
	selCh='';
	if (ii == 1) {
	    selCh='Davis Outside Temp';
	    pf = parseFloat(channelValues[selCh]);
	    pltScl=100.;
	    ustr=" F ";
	    cn="#c01n";
	    cv="#c01v";
	    cu="#c01u";
	    sl = smoothieLine1;
	    G2Gauge.set(pf);
	    $('#G2v').html(sprintf("Outdoor Temperature: %d F",pf));
	}
	if (ii == 2) {
	    selCh='Power'
	    pf = parseFloat(channelValues[selCh]);
	    pltScl=25000.;
	    ustr=" W ";
	    cn="#c02n";
	    cv="#c02v";
	    cu="#c02u";
	    sl = smoothieLine2;
	    G1Gauge.set(pf/1000.);
	    $('#G1v').html(sprintf("Power Consumption: %d kW",pf/1000));
	    	}
	if (ii == 3) {
	    selCh='DS_FLUID_IN'
	    pf = parseFloat(channelValues[selCh])
	    pltScl=100.;
	    ustr=" F ";
	    cn="#c03n";
	    cv="#c03v";
	    cu="#c03u";
	    sl = smoothieLine3;
	}
	if (ii == 4) {
	    selCh='DS_FLUID_OUT'
	    pf = parseFloat(channelValues[selCh])
	    pltScl=100.;
	    ustr=" F ";
	    cn="#c04n";
	    cv="#c04v";
	    cu="#c04u";
	    sl = smoothieLine4;
	}
	if (ii == 5) {
	    selCh='DS_DUTY_CYCLE'
	    pf = 100.*parseFloat(channelValues[selCh])
	    pltScl=100.;
	    ustr=" % ";
	    cn="#c05n";
	    cv="#c05v";
	    cu="#c05u";	    
	    sl = smoothieLine5;
	}
	if (ii == 6) {
	    selCh='Davis Humidity'
	    pf = parseFloat(channelValues[selCh])
	    pltScl=100.;
	    ustr="  ";
	    cn="#c06n";
	    cv="#c06v";
	    cu="#c06u";
	    sl = smoothieLine6;
	    G3Gauge.set(pf);
	    $('#G3v').html(sprintf("Outdoor Humidity: %d %%",pf));
	}
	if (ii == 7) {
	    selCh='UP_HVAC'
	    pf = parseFloat(channelValues[selCh])
	    pltScl=10.;
	    ustr="   ";
	    cn="#c07n";
	    cv="#c07v";
	    cu="#c07u";
	    sl = smoothieLine7;
	}
	if (ii == 8) {
	    selCh='DS_HVAC'
	    pf = parseFloat(channelValues[selCh])
	    pltScl=10.;
	    ustr="   ";
	    cn="#c08n";
	    cv="#c08v";
	    cu="#c08u";	    
	    sl = smoothieLine8;
	}
	if (ii == 9) {
	    selCh='AVG_EST_POWER'
	    pf = parseFloat(channelValues[selCh])
	    pltScl=25000.;
	    ustr=" F ";
	    cn="#c09n";
	    cv="#c09v";
	    cu="#c09u";
	    sl = smoothieLine9;
	}

	if (selCh != '') {
	    //console.log(selCh+" "+cn)
	    //G1 = Math.abs(pf/pltScl);
	    //G1 = (G1 - Math.trunc(G1))*10.
	    G1 = 10*(Math.abs(pf) % pltScl)/pltScl
	    sl.append(Utime.getTime(), G1);
	    $(cn).html(" "+selCh+": ");
	    $(cv).html(sprintf("%.2f",pf));
	    estr= ustr + "(" + sprintf("%f", pltScl) + ")";
	    $(cu).html(estr);
	    //console.log(pf, G1);
	}
    }
    //
    window.setTimeout(doPoll, pollLoopTime);
};
//
function didNotPoll() {
    nTimeOut = nTimeOut+1
    if (nTimeOut % 100 == 0) {
	timeOutAwake = false
    }
    console.log("***Polling Timeout*** Count: " + nTimeOut + " Awake: " + timeOutAwake);
    window.setTimeout(doPoll, pollLoopTime);
}
//
function doPoll() {
    //console.log("in doPoll");
    if (timeOutID){
	window.clearTimeout(timeOutID);
	timeOutAwake = true
    }
    getURL = "http://" + ipAddr + "/Query/"
    //console.log("About to GET: " + getURL);
    oReq.open("GET", getURL);
    //fire the missiles
    oReq.send();
    if (pollAwake) {
	timeOutID = window.setTimeout(didNotPoll, fastTimeOut);
    } else {
	timeOutID = window.setTimeout(didNotPoll, slowTimeOut);		     
    }
}
//
//set up listener for when server responds
//
const oReq = new XMLHttpRequest();
oReq.addEventListener("load", pollCB)
//
//
if (ipAddr !== '') { 
    doPoll();
} else {
    setTimeout(test, 100)
}
//
//
function smoothieSetup() {
    smoothie = new SmoothieChart(
	{grid:
	 {fillStyle:'#d9d9d9', sharpLines:true, millisPerLine:600000, verticalSections:10},
	 labels:
	 {fillStyle: '#000000', precision: 6},
	 timestampFormatter:SmoothieChart.timeFormatter,
	 millisPerPixel:6000, minValue: 0., maxValue: 10., interpolation:"Daisy"
	});
    var smoothieCanvas=document.getElementById("timeplot");
    smoothieLine1 = new TimeSeries();
    smoothieLine2 = new TimeSeries();
    smoothieLine3 = new TimeSeries();
    smoothieLine4 = new TimeSeries();
    smoothieLine5 = new TimeSeries();
    smoothieLine6 = new TimeSeries();
    smoothieLine7 = new TimeSeries();
    smoothieLine8 = new TimeSeries();
    smoothieLine9 = new TimeSeries();
    
    //
    smoothie.streamTo(smoothieCanvas,250) //250
    smoothie.addTimeSeries(smoothieLine1,
			   {lineWidth: 20, strokeStyle: '#009900', fillstyle:'#009900'});
    smoothie.addTimeSeries(smoothieLine2,
			   {lineWidth: 14, strokeStyle: '#3633ff', fillstyle:'#3633ff'});
    smoothie.addTimeSeries(smoothieLine3,
			   {lineWidth: 21, strokeStyle: '#ffff00', fillstyle:'#ffff00'});
    smoothie.addTimeSeries(smoothieLine4,
			   {lineWidth: 22, strokeStyle: '#ff0000', fillstyle:'#ff0000'});
    smoothie.addTimeSeries(smoothieLine5,
			   {lineWidth: 23, strokeStyle: '#ff00ff', fillstyle:'#ff00ff'});
    smoothie.addTimeSeries(smoothieLine6,
			   {lineWidth: 20, strokeStyle: '#663300', fillstyle:'#663300'});
    smoothie.addTimeSeries(smoothieLine7,
			   {lineWidth: 14, strokeStyle: '#808080', fillstyle:'#808080'});
    smoothie.addTimeSeries(smoothieLine8,
			   {lineWidth: 14, strokeStyle: '#800080', fillstyle:'#800080'});
    smoothie.addTimeSeries(smoothieLine9,
			   {lineWidth: 14, strokeStyle: '#ff6347', fillstyle:'#ff6347'});

}
function G123Setup(){
    //
    var G1Target = document.getElementById('G1');
    var G2Target = document.getElementById('G2');
    var G3Target = document.getElementById('G3');
    
    var G1Opts = {
	angle: 0.05, // The span of the gauge arc
	lineWidth: 0.35, // The line thickness
	radiusScale: .9, // Relative radius
	pointer: {
	    length: 0.6, // Relative to gauge radius
	    strokeWidth: 0.035, // The thickness
	    color: '#00FF00', // Fill color
	},
	renderTicks: {
	    divisions: 5,
	    subDivisions: 5,
	    divLength: 0.3,
	    subLength: 0.15
	},
	staticLabels: {
	    labels: [0,5,10,15,20,25],
	    color: 'white',
	    font: "90% Verdana"
	},
	limitMax: true,     // If false, max value increases automatically if value > maxValue
	limitMin: true,     // If true, the min value of the gauge will be fixed
	generateGradient: true,
	highDpiSupport: true,    // High resolution support
	colorStart: '#0039e6',   // Colors
	colorStop: '#0039e6',    // just experiment with them
	strokeColor: '#E0E0E0',  // to see which ones work best for you
	fontSize: 40,
	staticZones: [
	    {strokeStyle: "#008000", min: 0,  max: 10}, 
	    {strokeStyle: "#ffff00", min: 10, max: 20},
	    {strokeStyle: "#ff0000", min: 20, max: 25},
	],
    };
    var G2Opts = {
	angle: 0.05, // The span of the gauge arc
	lineWidth: 0.35, // The line thickness
	radiusScale: .9, // Relative radius
	pointer: {
	    length: 0.6, // Relative to gauge radius
	    strokeWidth: 0.035, // The thickness
	    color: '#00FF00', // Fill color
	},
	renderTicks: {
	    divisions: 6,
	    subDivisions: 5,
	    divLength: 0.3,
	    subLength: 0.15
	},
	staticLabels: {
	    labels: [-20,0,20,40,60,80,100],
	    color: 'white',
	    font: "90% Verdana"
	},
	limitMax: true,     // If false, max value increases automatically if value > maxValue
	limitMin: true,     // If true, the min value of the gauge will be fixed
	generateGradient: true,
	highDpiSupport: true,    // High resolution support
	colorStart: '#0039e6',   // Colors
	colorStop: '#0039e6',    // just experiment with them
	strokeColor: '#E0E0E0',  // to see which ones work best for you
	fontSize: 40,
	staticZones: [
	    {strokeStyle: "#0000ff", min: -20,  max: 40}, 
	    {strokeStyle: "#ffff00", min: 40, max: 80},
	    {strokeStyle: "#ff0000", min: 80, max: 100},
	],
    };
    var G3Opts = {
	angle: 0.05, // The span of the gauge arc
	lineWidth: 0.35, // The line thickness
	radiusScale: .9, // Relative radius
	pointer: {
	    length: 0.6, // Relative to gauge radius
	    strokeWidth: 0.035, // The thickness
	    color: '#00FF00', // Fill color
	},
	renderTicks: {
	    divisions: 6,
	    subDivisions: 4,
	    divLength: 0.3,
	    subLength: 0.15
	},
	staticLabels: {
	    labels: [40,50,60,70,80,90, 100],
	    color: 'white',
	    font: "90% Verdana"
	},
	limitMax: true,     // If false, max value increases automatically if value > maxValue
	limitMin: true,     // If true, the min value of the gauge will be fixed
	generateGradient: true,
	highDpiSupport: true,    // High resolution support
	colorStart: '#0039e6',   // Colors
	colorStop: '#0039e6',    // just experiment with them
	strokeColor: '#E0E0E0',  // to see which ones work best for you
	fontSize: 40,
	staticZones: [
	    {strokeStyle: "#0000ff", min: 40,  max: 60}, 
	    {strokeStyle: "#ffff00", min: 60, max: 80},
	    {strokeStyle: "#ff0000", min: 80, max: 100},
	],
    };


    
    //
    G1Gauge = new Gauge(G1Target).setOptions(G1Opts);
    G2Gauge = new Gauge(G2Target).setOptions(G2Opts);
    G3Gauge = new Gauge(G3Target).setOptions(G3Opts);
    //
    //G1 = power (kW)
    //
    G1Gauge.maxValue = 25; // set max gauge value
    G1Gauge.setMinValue(0);  // Prefer setter over gauge.minValue = 0
    G1Gauge.animationSpeed = 10; // set animation speed (32 is default value)
    //
    //G2 = Temp (F)
    //
    
    G2Gauge.maxValue = 100; // set max gauge value
    G2Gauge.setMinValue(-20);  // Prefer setter over gauge.minValue = 0
    G2Gauge.animationSpeed = 10; // set animation speed (32 is default value)
    //
    // G3 = Humidity
    //
    G3Gauge.maxValue = 100; // set max gauge value
    G3Gauge.setMinValue(40);  // Prefer setter over gauge.minValue = 0
    G3Gauge.animationSpeed = 10; // set animation speed (32 is default value)
}

//
//
function test() {
    var GG;
    var test1;
    var test2;
    //
    Ttime = Ttime + 100/1000    
    test1 = 5+5*Math.cos(6.28*Ttime/50)
    test2 = 60*Math.sin(6.28*Ttime/1000);
    GG = Math.abs(test2/10);
    GG = (GG - Math.trunc(GG))*10;
    Utime = new Date();
    smoothieLine1.append(Utime.getTime(), test1);
    smoothieLine2.append(Utime.getTime(), GG);
    if (0 == 0) {
	console.log(Ttime, test1, test2, GG)
    }
    if (Ttime <= 10000) {
	setTimeout(test, pollLoopTime)
    }
}
