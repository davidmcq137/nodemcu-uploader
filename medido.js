var flowRstr = 0;
var calFact = 0;
var gotFact = false;
var abcFact = 0;
var Ttime=0;
var Utime;
var timeOutID=null;
var nTimeOut=0;
var pollAwake = false;
const pollLoopTime=350;
const fastTimeOut=3*pollLoopTime;
const slowTimeOut=6*fastTimeOut;
var flowGauge;
var pressGauge;
var smoothie;
var smoothieLine1;
var smoothieLine2;
var timeOutAwake=true;
var slowSlider=0;
var GG;
var TTs;
var TTa;
var TTb;
//
// is all of this code REALLY inside ready fcn? need to fix that!
//
$(document).ready(function() {
    pressSetup();
    smoothieSetup();
    var ipAddr = location.host;
    var slider = document.getElementById("pumpSpeed");
    var sliderOutput = document.getElementById("pumpDisp");
    slider.oninput = function() {
	sliderOutput.innerHTML = this.value;
    }
    var pressLQ = 7.5; // default 7.5 psi (halfscale)
    $("#pressureLimit").on('input', function () {
	pressLQ = $("#pressureLimit").val();
	pressLQ = pressLQ/10;
	//console.log("pressLQ: " + pressLQ); 
	$("#pressureDisp").html(pressLQ);
    });
    var pressB=0;
    var lastB=2;
    $("#abcID").change(function(){
	abcFact = $("#abcID").val();
	pressGauge.set(abcFact)
	//console.log("var: ", $(this).val());
	//console.log("aadamsAudio.paused: " + aadamsAudio.paused);
	//console.log("aadamsAudio.currentTime: " + aadamsAudio.currentTime);
	//console.log("aadamsAudio.ended: " + aadamsAudio.ended);
	//if ($(this).val() == 0) {
	//    alert("zero");
	//    $("#Aadams").get(0).play();
	//} else {
	//    alert("not zero!")
	//    $("#Aadams").get(0).pause();
	//};
    });
    $("#Fill").click(function(){
	pressB = 1;
	//$("#Fill").text("-Fill-");
	//$("#Empty").text("Empty");
	$('.slider').css({backgroundColor: '#0400FF'});
	lastB = 1;
	smoothieLine1.data = [];
	smoothieLine2.data = [];
	smoothie.start();
    });
    $("#Empty").click(function(){
	pressB = 3;
	//$("#Empty").text("-Empty-");
	//$("#Fill").text("Fill");
	$('.slider').css({backgroundColor: '#FFCC00'});
	lastB = 3;
	smoothieLine1.data = [];
	smoothieLine2.data = [];
	smoothie.start()
    });
    $("#Off").click(function(){
	pressB = 2;
	//$("#Fill").text("Fill");	 
	//$("#Empty").text("Empty");
	//$("#Off").text("-Off-");
	lastB = 2;
	slider.value = 0;
	sliderOutput.innerHTML = 0;
	smoothie.stop();
    });     
    var pressC = 0;
    $(".buttonClear").click(function(){
	pressC = 1;
	alert("Timeouts: " + nTimeOut + " Resetting to 0")
	nTimeOut = 0;
    });
    $("#calID").change(function(){
	calFact = $("#calID").val();
    });
    //
    function pollCB() {
	var elems = oReq.responseText.split(",");
	//
	// elem[0]: Heap Size
	//
	var heapStr = Math.floor(Number(elems[0]));
	heapStr = heapStr.toFixed();
	$("#heapSize").html(heapStr)
	//
	// elem[1]: Total Fuel Flow (oz)
	//
	var flowCstr= Math.floor(Number(elems[1])*10)/10.;
	flowCstr = flowCstr.toFixed(1);
	$("#totalFuelFlow").html(flowCstr)
	var fuelModulo = Math.abs(flowCstr % 10);
	$('#fuelMeter').val(fuelModulo)
	//
	// elem[2]: Flow Rate (oz/min)
	//
	flowRstr = Math.floor(Number(Number(elems[2])) * 10) / 10.;
	flowRstr = flowRstr.toFixed(1);
	// this code copied from test .. needs to be tested live for daisy behavior
	GG = Math.abs(flowRstr/10);
	GG = (GG - Math.trunc(GG))*10;
	TTs = sprintf("%+06.2f", flowRstr);
	var i=TTs.indexOf(".");
	TTb=TTs.slice(0, i-1);
	TTa=TTs.slice(i-1);
	$("#fuelFlowRate").html(TTb+"<u>"+TTa+"</u>");
	//$("#fuelFlowRate").html(flowRstr)
	flowGauge.set(flowRstr)
	//
	// elem[3]: Running Time (secs)
	//
	var mins = Math.floor(Number(elems[3]) / 60);
	var secs = Math.floor(10 * (Number(elems[3]) - mins*60))/10.;
	var timeStr;
	timeStr = mins.toFixed().padStart(2,"0")+":"+secs.toFixed(1).padStart(4,"0");
	$("#runningTime").html(timeStr)
	//
	// elem[4]: Calibration factor (pulses per oz)
	//
	var ppOz = Math.floor( (Number(elems[4]) + 0.5)) / 100;
	if (!gotFact) {
	    calFact = ppOz.toFixed(2);
	    //console.log("calFact:" + calFact);
	    $("#calID").val(calFact);		 
	    gotFact = true;
	}
	//
	// elem[5]: Fuel pressure (psi)
	//
	var pressPSI = Number(elems[5]).toFixed(2);
	pressGauge.set(pressPSI)
	$('#fuelPressure').html(pressPSI)
	//
	// elem[6]: pumpPWM (0-1023)
	//
	var pumpPWM = Number(elems[6]);
	var pSpeed = 100 * pumpPWM / 1023;
	pSpeed = pSpeed.toFixed();
	//console.log(pumpPWM, pSpeed);
	$('#pumpRunSpeed').html(pSpeed);
	//
	// Reset next poll
	//
	var Utime=new Date();
	//console.log(Utime.getTime(), pressPSI);
	smoothieLine1.append(Utime.getTime(), pressPSI);
	smoothieLine2.append(Utime.getTime(), GG);
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
	//const oReq = new XMLHttpRequest();
	if (timeOutID){
	    window.clearTimeout(timeOutID);
	    timeOutAwake = true
	}
	//console.log(ipAddr)
	slowSlider = slowSlider - (slowSlider - slider.value)/1; // > 1 slows it down
	slowSlider = slowSlider.toFixed()
	var pumpURL = "http://" + ipAddr + "/Poll"
	var getURL = pumpURL + "?";
	getURL = getURL + "pS=" + slowSlider + "&";
	getURL = getURL + "pB=" + pressB + "&";
	getURL = getURL + "pC=" + pressC + "&";
	getURL = getURL + "pL=" + pressLQ*10;
	var temp = Math.floor(calFact * 100 + 0.5)
	if (calFact !== 0) {
	    getURL = getURL + "&cF=" + temp;
	};
	pressB = 0;
	pressC = 0;
	//console.log(getURL);
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
    if (ipAddr !== '') { 
	doPoll();
    } else {
	setTimeout(test, 100)
    }
    
    //
    //
    //
    function smoothieSetup() {
	smoothie = new SmoothieChart(
	    {grid:
	     {fillStyle:'#d9d9d9', sharpLines:true, millisPerLine:10000*2},
	     labels:
	     {fillStyle: '#d9d9d9', precision: 0},
	     //timestampFormatter:SmoothieChart.timeFormatter,
	     millisPerPixel:266, minValue: 0, maxValue: 10, interpolation:"BezierHazel"
	    });
	var smoothieCanvas=document.getElementById("timeplot");
	smoothieLine1 = new TimeSeries();
	smoothieLine2 = new TimeSeries();
	smoothie.streamTo(smoothieCanvas,250)
	smoothie.addTimeSeries(smoothieLine1,
			       {lineWidth: 2, strokeStyle: '#009900', fillstyle:'#ccffcc'});
	smoothie.addTimeSeries(smoothieLine2,
			       {lineWidth: 2, strokeStyle: '#0000FF', fillstyle:'#000099'});
    }
    function pressSetup(){
	//
	var flowTarget = document.getElementById('flowGauge');
	var pressTarget = document.getElementById('pressGauge');
	var flowOpts = {
	    angle: 0.05, // The span of the gauge arc
	    lineWidth: 0.35, // The line thickness
	    radiusScale: .9, // Relative radius
	    pointer: {
		length: 0.6, // Relative to gauge radius
		strokeWidth: 0.035, // The thickness
		color: '#000000', // Fill color
	    },
	    renderTicks: {
		divisions: 6,
		subDivisions: 4,
		divLength: 0.3,
		subLength: 0.15
	    },
	    staticLabels: {
		labels: [-60,-40,-20,0,20,40, 60],
		color: 'white',
		font: "90% sans serif"
	    },
	    limitMax: true,     // If false, max value increases automatically if value > maxValue
	    limitMin: true,     // If true, the min value of the gauge will be fixed
	    generateGradient: true,
	    highDpiSupport: true,     // High resolution support
	    colorStart: '#0039e6',   // Colors
	    colorStop: '#0039e6',    // just experiment with them
	    strokeColor: '#E0E0E0',  // to see which ones work best for you
	    fontSize: 30,
	    staticZones: [
		{strokeStyle: "#3633ff", min: -60, max: -2}, // 
		{strokeStyle: "#e0e0e0", min: -2,  max: 2},  // Grey near zero
		{strokeStyle: "#3633ff", min: 2,   max: 60}, // 
	    ],
	};
	var pressOpts = {
	    angle: 0.05, // The span of the gauge arc
	    lineWidth: 0.15, // The line thickness
	    radiusScale: .5, // Relative radius
	    pointer: {
		length: 0.0, //0.50, // // Relative to gauge radius
		strokeWidth: 0.035, // The thickness
		color: '#000000' // Fill color
	    },
	    renderTicks: {
		divisions: 5,
		subDivisions: 2,
		divLength: 0.3,
		subLength: 0.15
	    },
	    limitMax: true,     // If false, max value increases automatically if value > maxValue
	    limitMin: true,     // If true, the min value of the gauge will be fixed
	    generateGradient: true,
	    highDpiSupport: true,     // High resolution support
	    colorStart: '#0039e6',   // Colors
	    colorStop: '#0039e6',    // just experiment with them
	    strokeColor: '#E0E0E0',  // to see which ones work best for you
	    //fontSize: 30,
	    percentColors: [[0.0, "#009900" ], [1.0, "#009900"]],
	    strokeColor: '#E0E0E0',
	    //staticZones: [
	    //{strokeStyle: "#00FF00", min: 0, max: 2}, // 
	    //{strokeStyle: "#FF0000", min: 2, max: 5}, // 
	    //],
	};
	flowGauge = new Gauge(flowTarget).setOptions(flowOpts);
	pressGauge = new Gauge(pressTarget).setOptions(pressOpts);
	flowGauge.maxValue = 60; // set max gauge value
	flowGauge.setMinValue(-60);  // Prefer setter over gauge.minValue = 0
	flowGauge.animationSpeed = 10; // set animation speed (32 is default value)
	pressGauge.maxValue = 10; // set max gauge value
	pressGauge.setMinValue(0);  // Prefer setter over gauge.minValue = 0
	pressGauge.animationSpeed = 10; // set animation speed (32 is default value)
	
	pressGauge.set(abcFact); // set actual value	 
	flowGauge.set(flowRstr); // set actual value
    }
});
// //
function test() {
    var TpressPSI;
    var TflowCstr;
    var TfuelModulo;
    var TflowRstr;
    var TT;
    var GG;
    var GGLast=0;
    TpressPSI = 5+5*Math.cos(6.28*Ttime/10)
    pressGauge.set(TpressPSI);
    TT = "<u>" + TpressPSI.toFixed(1) + "</u>"
    $('#fuelPressure').html(TT)
    //
    TflowCstr = Ttime
    TT = TflowCstr.toFixed(2)
    $("#totalFuelFlow").html(TT)
    TfuelModulo = Math.abs(TflowCstr % 10);
    $('#fuelMeter').val(TfuelModulo)		     
    //
    TflowRstr = 60*Math.sin(6.28*Ttime/100);
    GG = Math.abs(TflowRstr/10);
    GG = (GG - Math.trunc(GG))*10;
    TT = sprintf("%+06.2f", TflowRstr);
    var i=TT.indexOf(".");
    TTb=TT.slice(0, i-1);
    TTa=TT.slice(i-1);
    //console.log(TT, TTb, TTa, GG);
    //TT = TflowRstr.toFixed(1);
    $("#fuelFlowRate").html(TTb+"<u>"+TTa+"</u>");
    //$("#fuelFlowRate").html("12<u>34</u>");
    flowGauge.set(TflowRstr);
    //
    Ttime = Ttime + 100/1000
    var Tmins = Math.floor(Ttime / 60);
    var Tsecs = Math.floor(10 * (Ttime - Tmins*60))/10.;
    var TtimeStr;
    TtimeStr = Tmins.toFixed().padStart(2,"0")+":"+Tsecs.toFixed(1).padStart(4,"0");
    $("#runningTime").html(TtimeStr)
    //
    Utime = new Date();
    //console.log(Utime.getTime(), TpressPSI);
    smoothieLine1.append(Utime.getTime(), TpressPSI);
    //smoothieLine2.append(Utime.getTime(), TflowRstr/12+5);
    //if (Math.abs(GG-GGLast) > 9) {
	//GG = NaN;
    //}
    smoothieLine2.append(Utime.getTime(), GG);
    GGLast = GG;
    if (Ttime <= 100) {
	setTimeout(test, pollLoopTime)
    }
}
