---
title: Building a 4x4x4 LED Cube. Part II; The software
date: 2016-02-01T21:54:12+02:00
draft: false
description: Writing the software for our 4x4x4 cube!
tags: Arduino, Shift Registers, LEDs, Bit Shifting, Cube, 4x4x4
icon: ⚡
---

It’s been awhile since I wrote about the LED cube I’ve been building and I figured it was about time I did the long planned followup where we take a closer look at the software that drives the cube.

If you’ve followed along with my earlier writings you’ll know that we’ve been building up to this point by first [driving 16 LEDs using only three pins of an Arduino](/posts/driving-16-leds-using-three-pins-of-aruino/) and then learned how to apply fading effects to the LEDs by taking a [deep dive in Bit Angle Modulation (BAM)](/posts/4-bit-angle-modulating/). In my previous post we’ve talked about [the hardware of the cube](posts/building-a-4x4x4-led-cube-part-i/) and in this post we’ll combine the pieces and learn how we can drive the individual LEDs in the cube.

## We’re just getting started and we’re already almost done

Ok, in the previous examples we’ve kept is relatively simple. Driving 16 LEDs using 595-shift registers.. Done. Applying fading effects using Bit Angle Modulation.. Done. But now we’re dealing with 64 individual LEDs. thats hard! Or is it?

Not really; if you think about it a 64 LED cube are just four layers of 16 LEDs, and we’ve already nailed that part. Lets have a look at a couple of changes we have to make to our existing codebase.

## Selecting a layer

The main difference between the cube setup and simply driving 16 LEDs is that we have to deal with multiple layers stacked on top of each other, so we need to find a way to select a specific layer to control.

Looking at my previous article about the hardware of this build you’ll see that we’ve added one extra shift register so we now have three instead of the two we used to drive the 16 LED example. This shift register is hooked up to four transistors which will complete the circuit once pulled high.

```ino
// turn on correct LED using 595's
void turnOnLed(int ledNr, int layer) {
  digitalWrite(latchPin, LOW);
  SPI.transfer(1<<layer);

  if (ledNr >= 8) {
    SPI.transfer(1<<ledNr-8);
    SPI.transfer(0);
  }
  else {
    SPI.transfer(0);
    SPI.transfer(1<<ledNr);
  }

  digitalWrite(latchPin, HIGH);
}
```

As you can see in the example included above we’ve extended our `turnOnLed()` function we’ve created in the BAM example to also take an integer called layer. We’re shifting `1 << layer` out first, which makes sure that a value between 1000 and 0001 (binary) will be pushed in first.

Followed by the actual LED information that will be pushed to the second and first shift register, this part is actually not changed when comparing to the BAM example.

_Note that we’re shifting MSBFIRST (Most Significant Bit First) here, so the layer information we’ve shifted out first will be pushed through to the last shift register when we’re shifting out the actual LED information._

## Keeping track of our four layers

Ok, so we can select a layer to control now. The next challenge is keeping track of the value of each LED. We’ve already dealt with BAM for 16 LEDs so we can basically just copy and paste the brightnessMask array from the BAM example three more times.

```ino
bool brightnessMask_layer1[NUMBER_OF_CONNECTED_LEDS*4];
bool brightnessMask_layer2[NUMBER_OF_CONNECTED_LEDS*4];
bool brightnessMask_layer3[NUMBER_OF_CONNECTED_LEDS*4];
bool brightnessMask_layer4[NUMBER_OF_CONNECTED_LEDS*4];
```

_Note that this is the solution I came up with since the language didn’t (and doesn’t?) allow me to define a multi-dimentional array here._

## Writing values for each layer

So we have our layer select part done, we’re keeping track of the value of each LED in each of our four layers. So what’s next? We need a way to write the correct value to the correct position of the `brightnessMask` array before we can shift it all out. Therefore I’ve changed up the `led()` function a bit.

```ino
void led(int x, int y, int z, int brightness){
   // ensure 4-bit limited brightness
  brightness = constrain(brightness, 0, 15);

  int ledNr = y*4+x;

  // turn 4-bit brightness into brightness mask
  for (int i = 3; i >= 0; i--) {
    if (brightness - (1 << i) >= 0) {
      brightness -= (1 << i);
      setBrightnessForLayerAddressValue(z, (ledNr*4)+i, true);
    }
    else{
      setBrightnessForLayerAddressValue(z, (ledNr*4)+i, false);
    }
  }

}

void setBrightnessForLayerAddressValue(int layer, int address, bool value){
  if(layer == 0){
    brightnessMask_layer1[address] = value;
  }
  else if(layer == 1){
    brightnessMask_layer2[address] = value;
  }
  else if(layer == 2){
    brightnessMask_layer3[address] = value;
  }
  else if(layer == 3){
    brightnessMask_layer4[address] = value;
  }
}
```

As you can see in the code snippet included above the led() function now accepts an x, y and z value along with its brightness value. Where the x and the y values obviously map to their corresponding LED on a given layer which is determined by the z parameter.

We’re determining the overall LED address (_integer_) by multiplying the y value by four and adding the x axis on top of that. Calculating the 4-bits based on the 0–15 brightness value is still the same as in the BAM example, but we’re delegating the outcome together with the layer information to `setBrightnessForLayerAddressValue` function which selects the correct brightnessMask array to write to.

## Shifting it all out

Okay, so now we’re able to select a layer, keep track of brightness information of each layer and writing brightness information to the brightnessMask. These were in fact the biggest changes, pushing this information to the cube is basically more of the same we already had.

```ino
void refresh(){

 // Loop over each LED
 for (int cycle = 0; cycle < 16; cycle++) {

   for (int currentLed = 0; currentLed < NUMBER_OF_CONNECTED_LEDS; currentLed++) {
     int maskPosition = currentLed * 4;
     if (cycle == 1 && brightnessMask_layer1[maskPosition]) {
       turnOnLed(currentLed, 0);
     }
     else if ((cycle == 2 || cycle == 3) && brightnessMask_layer1[maskPosition+1]) {
       turnOnLed(currentLed, 0);
     }
     else if (cycle >= 4 && cycle <= 7 && brightnessMask_layer1[maskPosition+2]) {
       turnOnLed(currentLed, 0);
     }
     else if (cycle >= 8 && cycle <= 15 && brightnessMask_layer1[maskPosition+3]) {
       turnOnLed(currentLed, 0);
     }
   }

   for (int currentLed = 0; currentLed < NUMBER_OF_CONNECTED_LEDS; currentLed++) {
     int maskPosition = currentLed * 4;
     if (cycle == 1 && brightnessMask_layer2[maskPosition]) {
       turnOnLed(currentLed, 1);
     }
     else if ((cycle == 2 || cycle == 3) && brightnessMask_layer2[maskPosition+1]) {
       turnOnLed(currentLed, 1);
     }
     else if (cycle >= 4 && cycle <= 7 && brightnessMask_layer2[maskPosition+2]) {
       turnOnLed(currentLed, 1);
     }
     else if (cycle >= 8 && cycle <= 15 && brightnessMask_layer2[maskPosition+3]) {
       turnOnLed(currentLed, 1);
     }
   }

   for (int currentLed = 0; currentLed < NUMBER_OF_CONNECTED_LEDS; currentLed++) {
     int maskPosition = currentLed * 4;
     if (cycle == 1 && brightnessMask_layer3[maskPosition]) {
       turnOnLed(currentLed, 2);
     }
     else if ((cycle == 2 || cycle == 3) && brightnessMask_layer3[maskPosition+1]) {
       turnOnLed(currentLed, 2);
     }
     else if (cycle >= 4 && cycle <= 7 && brightnessMask_layer3[maskPosition+2]) {
       turnOnLed(currentLed, 2);
     }
     else if (cycle >= 8 && cycle <= 15 && brightnessMask_layer3[maskPosition+3]) {
       turnOnLed(currentLed, 2);
     }
   }

   for (int currentLed = 0; currentLed < NUMBER_OF_CONNECTED_LEDS; currentLed++) {
     int maskPosition = currentLed * 4;
     if (cycle == 1 && brightnessMask_layer4[maskPosition]) {
       turnOnLed(currentLed, 3);
     }
     else if ((cycle == 2 || cycle == 3) && brightnessMask_layer4[maskPosition+1]) {
       turnOnLed(currentLed, 3);
     }
     else if (cycle >= 4 && cycle <= 7 && brightnessMask_layer4[maskPosition+2]) {
       turnOnLed(currentLed, 3);
     }
     else if (cycle >= 8 && cycle <= 15 && brightnessMask_layer4[maskPosition+3]) {
       turnOnLed(currentLed, 3);
     }
   }
   clearLeds();
 }

}
```

While this looks like a lot of code, it comes all down to this: Loop 16 times for one cycle, loop over the leds in and determine wether the LED should be turned on or off for the current cycle. Each cycle will call the `turnOnLed()` function we’ve already described above. **Repeat** this step for all four layers and we’re done!

## It’s a wrap

These where in fact the biggest changes. For the full source code have a look at [the gist](https://gist.github.com/Tmw/3a3f3d016a6592a989d8). In a future article we’ll be looking at how we can take these building blocks and create a neat little animation with it. Of course we’ll also be looking at how we can refactor our code since it gained quite some complexity to the point where it isn’t exactly DRY anymore ;)
