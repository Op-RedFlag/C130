var looptime = 0.2;
var en= 0;
var rpm = props.globals.getNode("engines/engine["~en~"]/rpm");
var cyltemp = props.globals.getNode("engines/engine["~en~"]/cylinder-temp-degc");
var exhtempf = props.globals.getNode("engines/engine["~ en ~"]/egt-degf");
var thrust = props.globals.getNode("engines/engine["~ en ~"]/thrust-lbs",1);
var carbetemp = props.globals.getNode("engines/engine["~ en ~"]/carburator-entry-temp-degc");
var manpress = props.globals.getNode("engines/engine["~ en ~"]/mp-osi");
var engstat = props.globals.getNode("engines/engine["~ en ~"]/running");
var engcrank = props.globals.getNode("engines/engine["~ en ~"]/cranking");
var primed = props.globals.getNode("engines/engine["~ en ~"]/primed");
var oiltemp = props.globals.getNode("engines/engine["~ en ~"]/oil-temperature-degf");
var blower = props.globals.getNode("controls/engines/engine["~ en ~"]/boost");
var airspeed = props.globals.getNode("velocities/airspeed-kt");
var envtemp = props.globals.getNode("environment/temperature-degc");
var cowlflap = props.globals.getNode("controls/engines/engine["~ en ~"]/cowl-flaps-norm");
var mixture = props.globals.getNode("controls/engines/engine["~ en ~"]/mixture");
var mixture0 = props.globals.getNode("controls/engines/engine["~ en ~"]/mixture0");
var viscosity = props.globals.getNode("engines/engine["~ en ~"]/oil-visc");
var rstrain = props.globals.getNode("engines/engine["~ en ~"]/rev-strain");
var oboost = props.globals.getNode("engines/engine["~ en ~"]/boost-strain");
var nofuel = props.globals.getNode("engines/engine["~ en ~"]/out-of-fuel",1 );
var gload = props.globals.getNode("accelerations/pilot-g",1);
var throttle = "controls/engines/engine["~ en ~"]/throttle";
var throttle_c ="controls/engines/engine["~ en ~"]/throttle-c";
var alt = "instrumentation/altimeter/pressure-alt-ft";
var boost = "controls/engines/engine["~ en ~"]/boost";
var mp_max = 46;
var mp_idle = 3;
var blowershiftalt = 13700;
var lowblower = 0.45;
var highblower = 1;

var init = func {
	var et0 = envtemp.getValue();
	#	print (et0);
	cyltemp.setDoubleValue (et0);
	
  if (getprop("/controls/engines/on-startup-running") == 1) {
  magicstart();
  }  else {
    nofuel.setAttribute("writable",0);

  }
  settimer(main_loop, looptime);
}
var main_loop = func {
#	print ("engstat: ", engstat.getValue());
	if (engstat.getValue() == 1){
  engine_update();
  fluid_update();
  check_engine();
  set_prop();
  set_boost();
	} else {
          nofuel.setAttribute("writable",0);
	  check_startup();
        }
  settimer(main_loop, looptime);
}


var engine_update = func {
# if someone has suggestions to calculate engine parameters more realistic drop me a note
	var as = airspeed.getValue();
	var cf = cowlflap.getValue();
	var ct = cyltemp.getValue();
	var et0 = envtemp.getValue();
	var egt = exhtempf.getValue();
	var ob = oboost.getValue();
	var rs = rstrain.getValue();
	var thr = thrust.getValue();
	#var thr = getprop("engines/engine["~ en ~"]/thrust-lbs"); # fixme: don't know why I have to do it this way
	var rpm0 = rpm.getValue();
	var mp = manpress.getValue();
	var mix = mixture.getValue();
	# calculate carburator entry temperature
	var cat = et0 + 0.6 * mp;
	#print ("CET: ",cat);
	carbetemp.setValue(cat);
	# summing up various parameters with a weighing factor
	var temp = 3 * cat + 0.3 * rpm0 + 0.5 * egt - 0.005 * as * as - 0.07* thr * (cf+0.1) -20 * mix ;
	#print ("Temp: ",temp,"Mix: ",mix);
	cyltemp.setDoubleValue (temp * 0.4);

# adjust throttle

	var throttle_s = getprop(throttle) * (mp_max);

#	print (throttle_s," ", getprop (throttle_c));

	if (getprop (throttle_c) > 1) {
  setprop (throttle_c,1);
	}
	if (getprop (throttle_c) < 0) {
  setprop (throttle_c,0);
	}

	var xx = getprop (throttle_c)  + ((throttle_s - manpress.getValue())*0.0015);

	interpolate (throttle_c, xx, looptime);
}

var set_boost = func {

	if (getprop(alt) > blowershiftalt) {
  setprop (boost, highblower);
  }
	if (getprop(alt) < blowershiftalt) {
  setprop (boost, lowblower);
  }
}
var set_prop = func {
  if (getprop("/controls/engines/engine[0]/prop-auto") == 1) {  
    ppitch = getprop("/controls/engines/engine[0]/propeller-pitch");
    mpress = manpress.getValue();  
      if (rpm.getValue() / mpress < 55.0)  {
          setprop("/controls/engines/engine[0]/propeller-pitch", ppitch + 0.003);
          }
      if (rpm.getValue() / mpress > 55.0)  {
          setprop("/controls/engines/engine[0]/propeller-pitch", ppitch - 0.003);
          }
      }
}

var fluid_update = func {
	var otemp = oiltemp.getValue();
	var visc = viscosity.getValue();
	# print (otemp," ",visc);
	interpolate ("engines/engine["~ en ~"]/oil-press", 8.2 - 2*visc, looptime);
	interpolate ("engines/engine["~ en ~"]/oil-temp-calc", otemp *visc-70, looptime);
	if (visc < 1.0 ) {
  interpolate ("engines/engine["~ en ~"]/oil-visc", visc + 0.002);

	}
}
var check_engine = func {
	var rs = rstrain.getValue();
	var ob = oboost.getValue();
	var rpm0 = rpm.getValue();
	var mp = manpress.getValue();

	if (getprop ("engines/engine["~ en ~"]/startup")) {
#  	print ("startup!");
  	setprop ("engines/engine["~ en ~"]/startup_smoke",1);
  	setprop ("engines/engine["~ en ~"]/startup",0);
  	settimer (func { setprop ("engines/engine["~ en ~"]/startup_smoke",0)},3);
	}	
	#check for overrev
	if (rpm0 > 3100) {
  var rs0 = 0.01 * (rpm0 - 3100) * ( rpm0 - 3100);
  rstrain.setValue (rs + rs0);
  # print (rs0, " ",rs + rs0);
	}
	if (rs > 300000 ) {
  setprop("/engines/engine["~ en ~"]/overrev", 1);
  failure.kill_engine();
	}	
	#check for overboost
	if (mp > 55) {
  var ob0 = ( mp - 57)*(mp - 57);
  oboost.setValue (ob + ob0);
  # print (ob0, " ",ob + ob0);"engines/engine["~ en ~"]/cylinder-temp-degc"
	}
	if (ob > 500 ) {
  setprop("/engines/engine["~ en ~"]/overboost", 1);
  failure.kill_engine();
	}
	if ( gload.getValue() < -0.3 ) {
  	print ("cutout!");
        setprop ("sim/messages/copilot", "Port engine starved of fuel by negative G-force!");
  	if (mixture0.getValue() == 0 ){
    	mixture0.setValue( mixture.getValue() );
    	mixture.setValue(0);
  	}
	} else {
  	if (mixture0.getValue() != 0 ) {
    	mixture.setValue( mixture0.getValue() );
    	mixture0.setValue(0);
  	}
	}
}

var check_startup = func {
  if (engstat.getValue() == 0){
  setprop ("engines/engine["~ en ~"]/crankloop",rpm.getValue()*0.008);
  if (getprop ("engines/engine["~ en ~"]/crankloop") > 1) {
    setprop ("engines/engine["~ en ~"]/crankloop",0);
  }
#	print (" engine off");
  if (engcrank.getValue() ) {
#	print (" commencing startup");


    if (rpm.getValue() >=200 and primed.getValue()>=1) {
      nofuel.setAttribute("writable",1);
      setprop ("engines/engine["~ en ~"]/startup",1);
    }
  } else {
  #  print ("no startup");
     setprop ("engines/engine["~ en ~"]/startup",0);
  }
	}


}

var cool_down = func {
#	print ("cooling");
	var et0 = envtemp.getValue();
	interpolate ("engines/engine["~ en ~"]/cylinder-temp-degc", et0, 300);
	interpolate ("engines/engine["~ en ~"]/oil-temp-calc", et0, 500);
	interpolate ("engines/engine["~ en ~"]/oil-visc" , 0, 500);
}


var magicstart = func {
    setprop("/consumables/fuel/tank[0]/selected",1);
    setprop("/consumables/fuel/tank[2]/selected",1);
    setprop("/controls/engines/engine["~ en ~"]/magnetos",3);
    setprop("/controls/engines/engine["~ en ~"]/coolflap-auto",1);
    setprop("/controls/engines/engine["~ en ~"]/radlever",1);
    setprop("/controls/engines/engine["~ en ~"]/propeller-pitch",0.5);
    setprop("/engines/engine["~ en ~"]/oil-visc",1);
    setprop("/engines/engine["~ en ~"]/rpm",800);
    setprop("/engines/engine["~ en ~"]/engine-running",1);
    nofuel.setAttribute("writable",1);
    setprop("/engines/engine["~ en ~"]/out-of-fuel",0);
}


var open_cowlflaps = func {
	if (cowlflap.getValue() < 1.0){
  setprop("controls/engines/engine["~ en ~"]/cowl-flaps-norm",1 );
	}
}
var close_cowlflaps = func {
	if (cowlflap.getValue() > 0.0){
  setprop("controls/engines/engine["~ en ~"]/cowl-flaps-norm",0 );
	}
}

var shift_blower_up = func {
	if (blower.getValue() <= 0.3){
  interpolate("controls/engines/engine["~ en ~"]/boost", 0.75, 45);
	}
	else {
  interpolate("controls/engines/engine["~ en ~"]/boost", 1.0, 45);
	}
}
var shift_blower_dn = func {
	if (blower.getValue() >= 1.0){
  interpolate("controls/engines/engine["~ en ~"]/boost", 0.75, 45);
	}
	else {
  interpolate("controls/engines/engine["~ en ~"]/boost", 0.3, 45);
	}
}

var starter = func {
	starter_power = getprop("/systems/electrical/volts");
	if(starter_power == nil)
  {starter_power = 0;}
	if (arg[0] == 1){
  if( starter_power > 5.0){ 
  	setprop("/controls/engines/engine["~ en ~"]/starter",1);
  }
  }else{
  	setprop("/controls/engines/engine["~ en ~"]/starter",0);}	
	}


setlistener("/sim/signals/fdm-initialized",init);
