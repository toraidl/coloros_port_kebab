<div align="center">


# ColorOS Porting Project

[简体中文](/README.md)&nbsp;&nbsp;|&nbsp;&nbsp;English

</div>

## Intro
- ColorOS Porting Project for OnePlus 8T

## Tested devices and portroms
- Test Base ROM: OnePlus 8T (ColorOS_14.0.0.600)

- Test Port ROM: OnePlus 12 (ColorOS_14.0.0.800), OnePlus ACE3V(ColorOS_14.0.1.621)

## Working
- Face unlock
- Fringerprint
- Camera
- Automatic Brightness
- NFC
- etc


## BUG


## How to use
- On WSL、ubuntu、deepin and other Linux
```shell
    sudo apt update
    sudo apt upgrade
    sudo apt install git -y
    # Clone project
    git clone https://github.com/toraidl/coloros_port_kebab.git
    cd coloros_port_kebab
    # Install dependencies
    sudo ./setup.sh
    # Start porting
    sudo ./port.sh <baserom> <portrom>
```
- baserom and portrom can be a direct download link. you can get the ota download link  from third-party websites.

## Credits
> In this project, some or all of the content is derived from the following open-source projects. Special thanks to the developers of these projects.

- [「BypassSignCheck」by Weverses](https://github.com/Weverses/BypassSignCheck)
- [「contextpatch」 by ColdWindScholar](https://github.com/ColdWindScholar/TIK)
- [「fspatch」by affggh](https://github.com/affggh/fspatch)
- [「gettype」by affggh](https://github.com/affggh/gettype)
- [「lpunpack」by unix3dgforce](https://github.com/unix3dgforce/lpunpack)
- [「miui_port」by ljc-fight](https://github.com/ljc-fight/miui_port)
- etc