---
title: Setting Up an eGPU on Ubuntu
description: >-
  I tend to use a laptop as my primary workstation. I love the portability, but
  dislike that I’m pretty much stuck with the hardware my…
date: 06/03/2020
categories: []
tags: ['ubuntu', 'egpu', 'linux', 'nvidia']
featured_image: img/1__fIHvmyrXHNPmaJpfvdvsBA.jpeg
slug: setting-up-an-egpu-on-ubuntu
---


I tend to use a laptop as my primary workstation. I love the portability, but dislike that I’m pretty much stuck with the hardware my system came with. On occasion I would like to be able to run games on my laptop that the built in Intel GPU just can’t cope with.

Since most modern laptops come with a thunderbolt connection, it’s now possible to use an external GPU to give a laptop more oomph. In Ubuntu this is pretty straightforward, but not exactly 100% plug and play.

#### How we can expect things to work

What I would like to be able to do is use this laptop with the built in Intel GPU so that I maximize battery life most of the time. When I want to use the eGPU, I should be able to plug that in to the thunderbolt port and either reboot and logout/login and be in Nvidia mode. I want to accelerate the display on my laptop, not an external monitor.

When done using the eGPU, I ought to be able to simply disconnect it and go back to low-power Intel GPU mode. Let’s try to set this up.

#### Checkout your BIOS

Before you get going, it may be a good idea to take a look at your BIOS settings. You will want to look for ‘Thunderbolt’ settings and verify that you have security disabled.

#### Setup Nvidia drivers

Firstly, you will want to install the Nvidia proprietary driver. This can be installed via the command line:

```
sudo apt-get install nvidia-driver-435
```

Or by plugging in your eGPU, going to ‘Software and Update’, going to the ‘Additional Drivers’ tab, and selecting the appropriate Nvidia driver that way.

Next you will need to allow Thunderbolt devices to authenticate

```
sudo echo 1 > sudo /sys/bus/thunderbolt/devices/0-0/0-1/nvm\_authenticate
```

#### Select the Nvidia prime profile

After installing drivers run:

```
nvidia-settings
```

Under PRIME Profiles, select ‘NVIDIA’.

#### Configure the driver

You will need to create an xorg.conf for the Nvidia driver:

sudo nvidia-xconfig --prime

The generated configuration gets us close, but not quite. Rebooting with my attached eGPU resulted in a blank screen and an error in /var/log/Xorg.0.log indicating ‘Screen(s) found, but none have a usable configuration’.

Edit /etc/X11/xorg.conf and add a line ‘Option “AllowExternalGpus” “True”\` to the device section for you Nvidia card. My section ends up looking like:

```
Section "Device"  
    Identifier     "Device0"  
    Driver         "nvidia"  
    VendorName     "NVIDIA Corporation"  
    BoardName      "GeForce GTX 660"  
    BusID          "PCI:9:0:0"  
    Option         "AllowExternalGpus" "True"  
EndSection
```

Your BusID, BoardName, etc will likely be somewhat different. Reboot and you should see the normal login screen.

#### Verify the setup

With the eGPU connected you should be able to verify things are working. Let’s see what our trusty friend ‘glxinfo’ has to say:

```
$ glxinfo | grep vendor  
server glx vendor string: NVIDIA Corporation  
client glx vendor string: NVIDIA Corporation  
OpenGL vendor string: NVIDIA Corporation
```

That’s what we want to see.

#### Add back your built in GPU

Next we need to add a section so our original built in Intel graphics work correctly. First we need to identify the built in GPU.

```
$ lspci | grep VGA  
00:02.0 VGA compatible controller: Intel Corporation UHD Graphics 620 (rev 07)
```

The first component ‘00:02.0’ is the BUS ID for this GPU. We then edit /etc/X11/xorg.conf one more time and create a section like the following:

```
Section "Device"  
    Identifier     "iris"  
    Driver         "modesetting"  
    BusID          "PCI:0:2:0"  
EndSection
```

Save the file. Now when you boot without the eGPU attached your system should work just like it did previously.

#### Usability

I find that this setup works pretty well and is generally trouble free. My laptop works just like before and has the same battery life as before. When I want to play a round of Cities Skylines, I plugin the eGPU, reboot and am good to go.

Typically just disconnecting the eGPU gets me back to Intel graphics automatically, albeit causing my session to logout. I happy with the setup and feel that it accomplishes the goals I set out.

#### Troubleshooting

A few tips for things that might go wrong:

*   Screen is blank when in eGPU mode — Double check the configuration above. Make sure that you have ‘AllowExternalGpus’ set.
*   I have a login screen but it never switches to the Nvidia driver. Verify that you have enabled the prime profile in nvidia-settings.
*   Screen work in eGPU but blank when not in eGPU mode — Verify your setup for the built in Intel GPU.
