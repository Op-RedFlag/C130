####    Experimental Aerostar electrical system    #### 
####    Syd Adams    ####
#### Based on Curtis Olson's nasal electrical code ####

var last_time = 0.0;
var bus_volts = 0.0;
var ammeter_ave = 0.0;

FDM = 0;
var OutPuts = "systems/electrical/outputs/"; 
var Volts = props.globals.getNode("/systems/electrical/volts",1);
var Amps = props.globals.getNode("/systems/electrical/amps",1);
var BATT = props.globals.getNode("/controls/electric/battery-switch",1);
var L1_ALT = props.globals.getNode("/controls/electric/engine[0]/generator",1);
var L2_ALT = props.globals.getNode("/controls/electric/engine[1]/generator",1);
var R1_ALT = props.globals.getNode("/controls/electric/engine[2]/generator",1);
var R2_ALT = props.globals.getNode("/controls/electric/engine[3]/generator",1);
var EXT  = props.globals.getNode("/controls/electric/external-power",1); 

#var battery = Battery.new(volts,amps,amp_hours,charge_percent,charge_amps);

Battery = {
  new : func {
  m = { parents : [Battery] };
    m.ideal_volts = arg[0];
    m.ideal_amps = arg[1];
    m.amp_hours = arg[2];
    m.charge_percent = arg[3]; 
    m.charge_amps = arg[4];
  return m;
  },
    
  apply_load : func {
    var amphrs_used = arg[0] * arg[1] / 3600.0;
    percent_used = amphrs_used / me.amp_hours;
    me.charge_percent -= percent_used;
    if ( me.charge_percent < 0.0 ) {
      me.charge_percent = 0.0;
    } elsif ( me.charge_percent > 1.0 ) {
      me.charge_percent = 1.0;
    }
    return me.amp_hours * me.charge_percent;
  },

  get_output_volts : func {
    x = 1.0 - me.charge_percent;
    tmp = -(3.0 * x - 1.0);
    factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
    return me.ideal_volts * factor;
  },

  get_output_amps : func {
    x = 1.0 - me.charge_percent;
    tmp = -(3.0 * x - 1.0);
    factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
    return me.ideal_amps * factor;
  }
};  

# var alternator = Alternator.new("rpm-source",rpm_threshold,volts,amps);
Alternator = {
  new : func {
    m = { parents : [Alternator] };
      m.rpm_source =  props.globals.getNode(arg[0],1);
      m.rpm_threshold = arg[1];
      m.ideal_volts = arg[2];
      m.ideal_amps = arg[3];
      return m;
    },

    apply_load : func( amps, dt) {
      var factor = me.rpm_source.getValue() / me.rpm_threshold;
      if ( factor > 1.0 ){factor = 1.0;}
      available_amps = me.ideal_amps * factor;
      return available_amps - amps;
    },

    get_output_volts : func {
      var factor = me.rpm_source.getValue() / me.rpm_threshold;
      if ( factor > 1.0 ) {
        factor = 1.0;
      }
      return me.ideal_volts * factor;
    },

    get_output_amps : func {
      var factor = me.rpm_source.getValue() / me.rpm_threshold;
      if ( factor > 1.0 ) {
        factor = 1.0;
      }
      return me.ideal_amps * factor;
    }
};

var battery = Battery.new(24,30,12,1.0,7.0);

alternator1 = Alternator.new("/engines/engine[0]/rpm",500.0,28.0,60.0);
alternator2 = Alternator.new("/engines/engine[1]/rpm",500.0,28.0,60.0);
alternator3 = Alternator.new("/engines/engine[2]/rpm",500.0,28.0,60.0);
alternator4 = Alternator.new("/engines/engine[3]/rpm",500.0,28.0,60.0);

var strobe_switch = props.globals.getNode("controls/lighting/strobe", 1);
aircraft.light.new("/controls/lighting/strobe-state", [0.05, 1.30], strobe_switch);
var beacon_switch = props.globals.getNode("controls/lighting/beacon", 1);
aircraft.light.new("/controls/lighting/beacon-state", [1.0, 1.0], beacon_switch);

#####################################
setlistener("/sim/signals/fdm-initialized", func {
  print("Electrical System ... ok");
  settimer(update_electrical,2);
});


var update_virtual_bus = func( dt ) {
  var PWR = props.globals.getNode("systems/electrical/serviceable",1).getBoolValue();
  var engine0_state = props.globals.getNode("/engines/engine[0]/running").getBoolValue();
  var engine1_state = props.globals.getNode("/engines/engine[1]/running").getBoolValue();
  var engine2_state = props.globals.getNode("/engines/engine[2]/running").getBoolValue();
  var engine3_state = props.globals.getNode("/engines/engine[3]/running").getBoolValue();
  var alternator1_volts = 0.0;
  var alternator2_volts = 0.0;
  var alternator3_volts = 0.0;
  var alternator4_volts = 0.0;
  battery_volts = battery.get_output_volts();
    
  if (engine0_state)alternator1_volts = alternator1.get_output_volts();
    props.globals.getNode("/engines/engine[0]/amp-v",1).setValue(alternator1_volts);

  if (engine1_state)alternator2_volts = alternator2.get_output_volts();
    props.globals.getNode("/engines/engine[1]/amp-v",1).setValue(alternator2_volts);

  if (engine2_state)alternator3_volts = alternator3.get_output_volts();
    props.globals.getNode("/engines/engine[1]/amp-v",1).setValue(alternator3_volts);

  if (engine3_state)alternator4_volts = alternator4.get_output_volts();
    props.globals.getNode("/engines/engine[1]/amp-v",1).setValue(alternator4_volts);

  external_volts = 0;
    load = 0;

  bus_volts = 0.0;
    power_source = nil;
    if ( BATT.getBoolValue()) {
      bus_volts = battery_volts * PWR;
      power_source = "battery";
    }
    if ( L1_ALT.getBoolValue() and (alternator1_volts > bus_volts) ) {
      bus_volts = alternator1_volts * PWR;
      power_source = "alternator1";
    }
    if ( L2_ALT.getBoolValue() and (alternator1_volts > bus_volts) ) {
      bus_volts = alternator2_volts * PWR;
      power_source = "alternator2";
    }
    if ( R1_ALT.getBoolValue() and (alternator3_volts > bus_volts) ) {
      bus_volts = alternator3_volts * PWR;
      power_source = "alternator3";
    }
    if ( R2_ALT.getBoolValue() and (alternator4_volts > bus_volts) ) {
      bus_volts = alternator4_volts * PWR;
      power_source = "alternator4";
    }
    if ( EXT.getBoolValue() and ( external_volts > bus_volts) ) {
      bus_volts = external_volts * PWR;
    }
   
    load += electrical_bus(bus_volts);
    load += avionics_bus(bus_volts);

    ammeter = 0.0;
    if ( bus_volts > 1.0 ) {
      load += 15.0;

      if ( power_source == "battery" ) {
        ammeter = -load;
      } else {
          ammeter = battery.charge_amps;
      }
    }
    if ( power_source == "battery" ) {
        battery.apply_load( load, dt );
    } elsif ( bus_volts > battery_volts ) {
      battery.apply_load( -battery.charge_amps, dt );
    }

    ammeter_ave = 0.8 * ammeter_ave + 0.2 * ammeter;

  Amps.setValue(ammeter_ave);
  Volts.setValue(bus_volts);
  return load;
}

var electrical_bus = func(){
  bus_volts = arg[0]; 
  load = 0.0;
  var starter_switch = props.globals.getNode("/controls/engines/engine[0]/starter").getBoolValue();
  var starter_switch1 = props.globals.getNode("/controls/engines/engine[1]/starter").getBoolValue();
  var starter_switch2 = props.globals.getNode("/controls/engines/engine[2]/starter").getBoolValue(); 
  var starter_switch3 = props.globals.getNode("/controls/engines/engine[3]/starter").getBoolValue(); 
  var starter_volts = bus_volts * starter_switch;
  starter_volts = bus_volts * starter_switch1;
  setprop(OutPuts~"starter",starter_volts); 
  load += getprop(OutPuts~"starter") * 0.1;
  var f_pump0 = getprop("/controls/engines/engine[0]/fuel-pump");
  var f_pump1 = getprop("/controls/engines/engine[1]/fuel-pump");
  var f_pump2 = getprop("/controls/engines/engine[2]/fuel-pump");
  var f_pump3 = getprop("/controls/engines/engine[3]/fuel-pump");
  setprop(OutPuts~"fuel-pump",bus_volts * f_pump0); 
  setprop(OutPuts~"fuel-pump",bus_volts * f_pump1); 
  setprop(OutPuts~"fuel-pump",bus_volts * f_pump2); 
  setprop(OutPuts~"fuel-pump",bus_volts * f_pump3); 
  load += getprop(OutPuts~"fuel-pump") * 0.02;
  setprop(OutPuts~"pitot-heat",bus_volts * getprop("/controls/anti-ice/pitot-heat")); 
  setprop(OutPuts~"landing-lights",bus_volts * getprop("/controls/lighting/landing-lights")); 
  setprop(OutPuts~"cabin-lights",bus_volts * getprop("/controls/lighting/cabin-lights")); 
  setprop(OutPuts~"wing-lights",bus_volts * getprop("/controls/lighting/wing-lights")); 
  setprop(OutPuts~"nav-lights",bus_volts * getprop("/controls/lighting/nav-lights")); 
  setprop(OutPuts~"beacon",bus_volts * getprop("/controls/lighting/beacon")); 
  setprop(OutPuts~"flaps",bus_volts); 
  return load;
}

#### used in Instruments/source code 
# adf : dme : encoder : gps : DG : transponder  
# mk-viii : MRG : tacan : turn-coordinator
# nav[0] : nav [1] : comm[0] : comm[1]
####

var avionics_bus = func(){
  bus_volts = arg[0];
  load = 0.0;
  var I_DIM = getprop("controls/lighting/instruments-norm");
  setprop(OutPuts~"instrument-lights",(bus_volts * I_DIM)*getprop("controls/lighting/instrument-lights")); 
  setprop(OutPuts~"radar",bus_volts); 
  setprop(OutPuts~"adf",bus_volts); 
  setprop(OutPuts~"dme",bus_volts); 
  setprop(OutPuts~"encoder",bus_volts); 
  setprop(OutPuts~"gps",bus_volts); 
  setprop(OutPuts~"DG",bus_volts); 
  setprop(OutPuts~"transponder",bus_volts); 
  setprop(OutPuts~"mk-viii",bus_volts); 
  setprop(OutPuts~"MRG",bus_volts); 
  setprop(OutPuts~"tacan",bus_volts); 
  setprop(OutPuts~"turn-coordinator",bus_volts); 
  setprop(OutPuts~"nav[0]",bus_volts); 
  setprop(OutPuts~"nav[1]",bus_volts); 
  setprop(OutPuts~"comm[0]",bus_volts); 
  setprop(OutPuts~"comm[1]",bus_volts); 
  load +=15;
  return load;
}

var update_electrical = func{
  time = getprop("/sim/time/elapsed-sec");
  dt = time - last_time;
  last_time = time;
  update_virtual_bus( dt );

  settimer(update_electrical, 0);
}
