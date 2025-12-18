# C20KBareMON

A small monitor program that is loaded to the OS ROM area at F000 and provides
the facility to read and write memory and start programs running.


## minicom

Minicom needs to be set to add some delay after newlines to allow processing to 
proceed

```ctrl-a T, D``` to access line delay - set to 50ms

```ctrl-a O, File transfer settings, I ascii,``` change to:
```	ascii	ascii-xfr -dsv -l 50```

To send hex files

```ctrl-a S, ascii```


If after transfer the file has "?" markers appearing after each line then try
increasing the inter-line delay


### connect from Windows

To connect the windows usb port to WSL2 first install usbipd then in 
powershell:

```C:\> usbipd list```

to find the device

```C:\> usbipd attach --wsl --busid=10-1```

to attach in WSL2 - the device should show as /dev/ttyUSBx I had to then run
```$ sudo stty -F /dev/ttyUSB1``` before the device would behave.



