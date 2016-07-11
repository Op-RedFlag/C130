###############################################
# Drogues system by Jano. Thanks to him. 2010 #
###############################################

toggle_refuelling_drogues = func {

  if(getprop("controls/refuelling/refuelling-drogues-pos-norm") > 0) {

    interpolate("controls/refuelling/refuelling-drogues-pos-norm", 0, 5);

    settimer( func() { setprop("tanker", 0); }, 0);  

  } else {

    interpolate("controls/refuelling/refuelling-drogues-pos-norm", 1, 5);

    settimer( func() { if (getprop("controls/refuelling/refuelling-drogues-pos-norm") == 1 ) setprop("tanker", 1) 
    
  else setprop("tanker", 0); }, 6);

  }

}
