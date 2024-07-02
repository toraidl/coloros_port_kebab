#!/bin/bash

# ColorOS_port project

# For A-only and V/A-B (not tested) Devices

# Based on Android 14 

# Test Base ROM: OnePlus 8T (ColorOS_14.0.0.600)

# Test Port ROM: OnePlus 12 (ColorOS_14.0.0.810), OnePlus ACE3V(ColorOS_14.0.1.621) Realme GT Neo5 240W(RMX3708_14.0.0.800)

build_user="Bruce Teng"
build_host=$(hostname)

# 底包和移植包为外部参数传入
baserom="$1"
portrom="$2"

work_dir=$(pwd)
tools_dir=${work_dir}/bin/$(uname)/$(uname -m)
export PATH=$(pwd)/bin/$(uname)/$(uname -m)/:$PATH

# Import functions
source functions.sh

shopt -s expand_aliases
if [[ "$OSTYPE" == "darwin"* ]]; then
    yellow "检测到Mac，设置alias" "macOS detected,setting alias"
    alias sed=gsed
    alias tr=gtr
    alias grep=ggrep
    alias du=gdu
    alias date=gdate
    #alias find=gfind
fi


check unzip aria2c 7z zip java zipalign python3 zstd bc xmlstarlet

# 可在 bin/port_config 中更改
super_list=$(grep "possible_super_list" bin/port_config |cut -d '=' -f 2)
repackext4=$(grep "repack_with_ext4" bin/port_config |cut -d '=' -f 2)
super_extended=$(grep "super_extended" bin/port_config |cut -d '=' -f 2)
if [[ ${repackext4} == true ]]; then
    pack_type=EXT
else
    pack_type=EROFS
fi


# 检查为本地包还是链接
if [ ! -f "${baserom}" ] && [ "$(echo $baserom |grep http)" != "" ];then
    blue "底包为一个链接，正在尝试下载" "Download link detected, start downloding.."
    aria2c --max-download-limit=1024M --file-allocation=none -s10 -x10 -j10 ${baserom}
    baserom=$(basename ${baserom} | sed 's/\?t.*//')
    if [ ! -f "${baserom}" ];then
        error "下载错误" "Download error!"
    fi
elif [ -f "${baserom}" ];then
    green "底包: ${baserom}" "BASEROM: ${baserom}"
else
    error "底包参数错误" "BASEROM: Invalid parameter"
    exit
fi

if [ ! -f "${portrom}" ] && [ "$(echo ${portrom} |grep http)" != "" ];then
    blue "移植包为一个链接，正在尝试下载"  "Download link detected, start downloding.."
    aria2c --max-download-limit=1024M --file-allocation=none -s10 -x10 -j10 ${portrom}
    portrom=$(basename ${portrom} | sed 's/\?t.*//')
    if [ ! -f "${portrom}" ];then
        error "下载错误" "Download error!"
    fi
elif [ -f "${portrom}" ];then
    green "移植包: ${portrom}" "PORTROM: ${portrom}"
else
    error "移植包参数错误" "PORTROM: Invalid parameter"
    exit
fi

if [ "$(echo $baserom |grep ColorOS_)" != "" ];then
    device_code=$(basename $baserom |cut -d '_' -f 2)
else
    device_code="op8t"
fi

blue "正在检测ROM底包" "Validating BASEROM.."
if unzip -l ${baserom} | grep -q "payload.bin"; then
    baserom_type="payload"
elif unzip -l ${baserom} | grep -q "br$";then
    baserom_type="br"
else
    error "底包中未发现payload.bin以及br文件，请使用ColorOS官方包后重试" "payload.bin/new.br not found, please use  ColorOS official OTA zip package."
    exit
fi

blue "开始检测ROM移植包" "Validating PORTROM.."
if unzip -l ${portrom} | grep  -q "payload.bin"; then
    green "ROM初步检测通过" "ROM validation passed."
else
    error "目标移植包没有payload.bin，请用MIUI官方包作为移植包" "payload.bin not found, please use ColorOS official OTA zip package."
fi

green "ROM初步检测通过" "ROM validation passed."

blue "正在清理文件" "Cleaning up.."
for i in ${port_partition};do
    [ -d ./${i} ] && rm -rf ./${i}
done
sudo rm -rf app
sudo rm -rf tmp
sudo rm -rf config
sudo rm -rf build/baserom/
sudo rm -rf build/portrom/
find . -type d -name 'ColorOS_*' |xargs rm -rf

green "文件清理完毕" "Files cleaned up."
mkdir -p build/baserom/images/

mkdir -p build/portrom/images/


# 提取分区
if [[ ${baserom_type} == 'payload' ]];then
    blue "正在提取底包 [payload.bin]" "Extracting files from BASEROM [payload.bin]"
    unzip ${baserom} payload.bin -d build/baserom > /dev/null 2>&1 ||error "解压底包 [payload.bin] 时出错" "Extracting [payload.bin] error"
    green "底包 [payload.bin] 提取完毕" "[payload.bin] extracted."

    blue "开始分解底包 [payload.bin]" "Unpacking BASEROM [payload.bin]"
    payload-dumper-go -o build/baserom/images/ build/baserom/payload.bin >/dev/null 2>&1 ||error "分解底包 [payload.bin] 时出错" "Unpacking [payload.bin] failed"
elif [[ ${baserom_type} == 'br' ]];then
    blue "正在提取底包 [new.dat.br]" "Extracting files from BASEROM [*.new.dat.br]"
    unzip ${baserom} -d build/baserom  > /dev/null 2>&1 || error "解压底包 [new.dat.br]时出错" "Extracting [new.dat.br] error"
    green "底包 [new.dat.br] 提取完毕" "[new.dat.br] extracted."
    blue "开始分解底包 [new.dat.br]" "Unpacking BASEROM[new.dat.br]"
    for file in build/baserom/*; do
        filename=$(basename -- "$file")
        extension="${filename##*.}"
        name="${filename%.*}"

        if [[ $name =~ [0-9] ]];then
            new_name=$(echo "$name" | sed 's/[0-9]\+\(\.[^0-9]\+\)/\1/g')
            new_name=$(echo "$new_name" | sed 's/\.\./\./g')
            new_filename=$new_name.$extension

            mv -fv $file build/baserom/$new_filename 
        fi
    done
    for i in ${super_list}; do 
        ${tools_dir}/brotli -d build/baserom/$i.new.dat.br >/dev/null 2>&1
        sudo python3 ${tools_dir}/sdat2img.py build/baserom/$i.transfer.list build/baserom/$i.new.dat build/baserom/images/$i.img >/dev/null 2>&1
        rm -rf build/baserom/$i.new.dat* build/baserom/$i.transfer.list build/baserom/$i.patch.*
    done
fi

blue "正在提取移植包 [payload.bin]" "Extracting files from PORTROM [payload.bin]"
    unzip ${portrom} payload.bin -d build/portrom  > /dev/null 2>&1 ||error "解压移植包 [payload.bin] 时出错"  "Extracting [payload.bin] error"
    green "移植包 [payload.bin] 提取完毕" "[payload.bin] extracted."


for part in system product system_ext my_product my_manifest ;do
    extract_partition build/baserom/images/${part}.img build/baserom/images    
done

# Move those to portrom folder. We need to pack those imgs into final port rom
for image in vendor odm my_company my_preload;do
    if [ -f build/baserom/images/${image}.img ];then
        mv -f build/baserom/images/${image}.img build/portrom/images/${image}.img

        # Extracting vendor at first, we need to determine which super parts to pack from Baserom fstab. 
        extract_partition build/portrom/images/${image}.img build/portrom/images/

    fi
done

# Extract the partitions list that need to pack into the super.img
#super_list=$(sed '/^#/d;/^\//d;/overlay/d;/^$/d;/\^loop/d' build/portrom/images/vendor/etc/fstab.qcom \
#                | awk '{ print $1}' | sort | uniq)

# 分解镜像
green "开始提取逻辑分区镜像" "Starting extract portrom partition from img"
for part in ${super_list};do
# Skip already extraced parts from BASEROM
    if [[ ! -d build/portrom/images/${part} ]]; then
        blue "payload.bin 提取 [${part}] 分区..." "Extracting [${part}] from PORTROM payload.bin"

        payload-dumper-go -p ${part} -o build/portrom/images/ build/portrom/payload.bin || error "提取移植包 [${part}] 分区时出错" "Extracting partition [${part}] error."
        extract_partition "${work_dir}/build/portrom/images/${part}.img" "${work_dir}/build/portrom/images/"
        rm -rf ${work_dir}/build/baserom/images/${part}.img
    else
        yellow "跳过从PORTORM提取分区[${part}]" "Skip extracting [${part}] from PORTROM"
    fi
done
rm -rf config

blue "正在获取ROM参数" "Fetching ROM build prop."

# 安卓版本
base_android_version=$(< build/baserom/images/my_product/build.prop grep "ro.build.version.oplusrom" |awk 'NR==1' |cut -d '=' -f 2)
port_android_version=$(< build/portrom/images/my_product/build.prop grep "ro.build.version.oplusrom" |awk 'NR==1' |cut -d '=' -f 2)
green "安卓版本: 底包为[Android ${base_android_version}], 移植包为 [Android ${port_android_version}]" "Android Version: BASEROM:[Android ${base_android_version}], PORTROM [Android ${port_android_version}]"

# SDK版本
base_android_sdk=$(< build/baserom/images/system/system/build.prop grep "ro.system.build.version.sdk" |awk 'NR==1' |cut -d '=' -f 2)
port_android_sdk=$(< build/portrom/images/system/system/build.prop grep "ro.system.build.version.sdk" |awk 'NR==1' |cut -d '=' -f 2)
green "SDK 版本: 底包为 [SDK ${base_android_sdk}], 移植包为 [SDK ${port_android_sdk}]" "SDK Verson: BASEROM: [SDK ${base_android_sdk}], PORTROM: [SDK ${port_android_sdk}]"

# ROM版本
base_rom_version=$(<  build/baserom/images/my_manifest/build.prop grep "ro.build.display.ota" | awk 'NR==1' | cut -d '=' -f 2 | cut -d "_" -f 2-)
port_rom_version=$(<  build/portrom/images/my_manifest/build.prop grep "ro.build.display.ota" | awk 'NR==1' | cut -d '=' -f 2 | cut -d "_" -f 2-)
green "ROM 版本: 底包为 [${base_rom_version}], 移植包为 [${port_rom_version}]" "ROM Version: BASEROM: [${base_rom_version}], PORTROM: [${port_rom_version}] "

#ColorOS版本号获取

base_device_code=$(< build/baserom/images/my_manifest/build.prop grep "ro.oplus.version.my_manifest" | awk 'NR==1' | cut -d '=' -f 2 | cut -d "_" -f 1)
port_device_code=$(< build/portrom/images/my_manifest/build.prop grep "ro.oplus.version.my_manifest" | awk 'NR==1' | cut -d '=' -f 2 | cut -d "_" -f 1)

green "机型代号: 底包为 [${base_device_code}], 移植包为 [${port_device_code}]" "Device Code: BASEROM: [${base_device_code}], PORTROM: [${port_device_code}]"
# 代号
base_product_device=$(< build/baserom/images/my_manifest/build.prop grep "ro.product.device" |awk 'NR==1' |cut -d '=' -f 2)
port_product_device=$(< build/portrom/images/my_manifest/build.prop grep "ro.product.device" |awk 'NR==1' |cut -d '=' -f 2)
green "机型代号: 底包为 [${base_product_device}], 移植包为 [${port_product_device}]" "Product Device: BASEROM: [${base_product_device}], PORTROM: [${port_product_device}]"

base_product_name=$(< build/baserom/images/my_manifest/build.prop grep "ro.product.name" |awk 'NR==1' |cut -d '=' -f 2)
port_product_name=$(< build/portrom/images/my_manifest/build.prop grep "ro.product.name" |awk 'NR==1' |cut -d '=' -f 2)
green "机型代号: 底包为 [${base_product_name}], 移植包为 [${port_product_name}]" "Product Name: BASEROM: [${base_product_name}], PORTROM: [${port_product_name}]"

base_rom_model=$(< build/baserom/images/my_manifest/build.prop grep "ro.product.model" |awk 'NR==1' |cut -d '=' -f 2)
port_rom_model=$(< build/portrom/images/my_manifest/build.prop grep "ro.product.model" |awk 'NR==1' |cut -d '=' -f 2)
green "机型代号: 底包为 [${base_rom_model}], 移植包为 [${port_rom_model}]" "Product Model: BASEROM: [${base_rom_model}], PORTROM: [${port_rom_model}]"

base_market_name=$(< build/portrom/images/odm/build.prop grep "ro.vendor.oplus.market.name" |awk 'NR==1' |cut -d '=' -f 2)
port_market_name=$(grep -r --include="*.prop"  --exclude-dir="odm" "ro.vendor.oplus.market.name" build/portrom/images/ | head -n 1 | awk "NR==1" | cut -d "=" -f2)

green "机型代号: 底包为 [${base_market_name}], 移植包为 [${port_market_name}]" "Market Name: BASEROM: [${base_market_name}], PORTROM: [${port_market_name}]"

base_my_product_type=$(< build/baserom/images/my_product/build.prop grep "ro.oplus.image.my_product.type" |awk 'NR==1' |cut -d '=' -f 2)
port_my_product_type=$(< build/portrom/images/my_product/build.prop grep "ro.oplus.image.my_product.type" |awk 'NR==1' |cut -d '=' -f 2)

target_display_id=$(< build/portrom/images/my_manifest/build.prop grep "ro.build.display.id" |awk 'NR==1' |cut -d '=' -f 2 | sed 's/$port_device_code/$base_device_code)/g')

green "机型代号: 底包为 [${base_rom_model}], 移植包为 [${port_rom_model}]" "My Product Type: BASEROM: [${base_rom_model}], PORTROM: [${port_rom_model}]"

base_vendor_brand=$(< build/baserom/images/my_manifest/build.prop grep "ro.product.vendor.brand" |awk 'NR==1' |cut -d '=' -f 2)
port_vendor_brand=$(< build/portrom/images/my_manifest/build.prop grep "ro.product.vendor.brand" |awk 'NR==1' |cut -d '=' -f 2)

# Security Patch Date
portrom_version_security_patch=$(< build/portrom/images/my_manifest/build.prop grep "ro.build.version.security_patch" |awk 'NR==1' |cut -d '=' -f 2 )

if grep -q "ro.build.ab_update=true" build/portrom/images/vendor/build.prop;  then
    is_ab_device=true
else
    is_ab_device=false

fi

rm -rf build/portrom/images/my_manifest
cp -rf build/baserom/images/my_manifest build/portrom/images/
cp -rf build/baserom/images/config/my_manifest_* build/portrom/images/config/
sed -i "s/ro.build.display.id=.*/ro.build.display.id=${target_display_id}/g" build/portrom/images/my_manifest/build.prop
sed -i "s/ro.build.version.security_patch=.*/ro.build.version.security_patch=${portrom_version_security_patch}/g" build/portrom/images/my_manifest/build.prop

if [[ ! -d tmp ]];then
    mkdir -p tmp/
fi

 mkdir -p tmp/services/
 cp -rf build/portrom/images/system/system/framework/services.jar tmp/services.jar

java -jar bin/apktool/APKEditor.jar d -f -i tmp/services.jar -o tmp/services  > /dev/null 2>&1
declare -A smali_to_methods=()

smali_to_methods[ScanPackageUtils]="--assertMinSignatureSchemeIsValid"

for smali in ${!smali_to_methods[@]}; do
    target_file=$(find tmp/services -type f -name "${smali}.smali")
    echo "smali is $smali"
    echo "target_file is $target_file"
    if [[ -f $target_file ]]; then
        methods=${smali_to_methods[$smali]}
        for method in $methods; do 
            python3 bin/patchmethod.py $target_file $method && blue "${target_file}  修改成功" "${target_file} patched"
        done
    fi
done

target_method='getMinimumSignatureSchemeVersionForTargetSdk' 
    old_smali_dir=""
    declare -a smali_dirs

    while read -r smali_file; do
        smali_dir=$(echo "$smali_file" | cut -d "/" -f 3)

        if [[ $smali_dir != $old_smali_dir ]]; then
            smali_dirs+=("$smali_dir")
        fi

        method_line=$(grep -n "$target_method" "$smali_file" | cut -d ':' -f 1)
        register_number=$(tail -n +"$method_line" "$smali_file" | grep -m 1 "move-result" | tr -dc '0-9')
        move_result_end_line=$(awk -v ML=$method_line 'NR>=ML && /move-result /{print NR; exit}' "$smali_file")
        orginal_line_number=$method_line
        replace_with_command="const/4 v${register_number}, 0x0"
        { sed -i "${orginal_line_number},${move_result_end_line}d" "$smali_file" && sed -i "${orginal_line_number}i\\${replace_with_command}" "$smali_file"; } && blue "${smali_file}  修改成功" "${smali_file} patched"
        old_smali_dir=$smali_dir
    done < <(find tmp/services/smali/*/com/android/server/pm/ tmp/services/smali/*/com/android/server/pm/pkg/parsing/ -maxdepth 1 -type f -name "*.smali" -exec grep -H "$target_method" {} \; | cut -d ':' -f 1)
 

java -jar bin/apktool/APKEditor.jar b -f -i tmp/services -o tmp/services_patched.jar > /dev/null 2>&1
cp -rf tmp/services_patched.jar build/portrom/images/system/system/framework/services.jar

#Unlock AI CAll
patch_smali "HeyTapSpeechAssist.apk" "jc/a.smali" "PHY120" "KB2000"

patch_smali "HeyTapSpeechAssist.apk" "tc/a.smali" "PHY120" "KB2000"

yellow "删除多余的App" "Debloating..." 
# List of apps to be removed

debloat_apps=()
#kept_apps=("Clock" "FileManager" "KeKeThemeSpace" "SogouInput" "Weather" "Calendar")
kept_apps=()
if [[ $super_extended == "false" ]] && [[ $base_rom_model == "KB2000" ]];then
    for delapp in $(find build/portrom/images/ -maxdepth 3 -path "*/del-app/*" -type d ); do
        app_name=$(basename ${delapp})
        
        keep=false
        for kept_app in "${kept_apps[@]}"; do
            if [[ $app_name == *"$kept_app"* ]]; then
                keep=true
                break
            fi
        done
        
        if [[ $keep == false ]]; then
            debloat_apps+=("$app_name")
        fi

    done
fi

for debloat_app in "${debloat_apps[@]}"; do
    # Find the app directory
    app_dir=$(find build/portrom/images/ -type d -name "*$debloat_app*")
    
    # Check if the directory exists before removing
    if [[ -d "$app_dir" ]]; then
        yellow "删除目录: $app_dir" "Removing directory: $app_dir"
        rm -rf "$app_dir"
    fi
done
rm -rf build/portrom/images/product/etc/auto-install*
rm -rf build/portrom/images/system/verity_key
rm -rf build/portrom/images/vendor/verity_key
rm -rf build/portrom/images/product/verity_key
rm -rf build/portrom/images/system/recovery-from-boot.p
rm -rf build/portrom/images/vendor/recovery-from-boot.p
rm -rf build/portrom/images/product/recovery-from-boot.p

# build.prop 修改
blue "正在修改 build.prop" "Modifying build.prop"
#
#change the locale to English
export LC_ALL=en_US.UTF-8
buildDate=$(date -u +"%a %b %d %H:%M:%S UTC %Y")
buildUtc=$(date +%s)
for i in $(find build/portrom/images -type f -name "build.prop");do
    blue "正在处理 ${i}" "modifying ${i}"
    sed -i "s/ro.build.date=.*/ro.build.date=${buildDate}/g" ${i}
    sed -i "s/ro.build.date.utc=.*/ro.build.date.utc=${buildUtc}/g" ${i}
    sed -i "s/ro.odm.build.date=.*/ro.odm.build.date=${buildDate}/g" ${i}
    sed -i "s/ro.odm.build.date.utc=.*/ro.odm.build.date.utc=${buildUtc}/g" ${i}
    sed -i "s/ro.vendor.build.date=.*/ro.vendor.build.date=${buildDate}/g" ${i}
    sed -i "s/ro.vendor.build.date.utc=.*/ro.vendor.build.date.utc=${buildUtc}/g" ${i}
    sed -i "s/ro.system.build.date=.*/ro.system.build.date=${buildDate}/g" ${i}
    sed -i "s/ro.system.build.date.utc=.*/ro.system.build.date.utc=${buildUtc}/g" ${i}
    sed -i "s/ro.product.build.date=.*/ro.product.build.date=${buildDate}/g" ${i}
    sed -i "s/ro.product.build.date.utc=.*/ro.product.build.date.utc=${buildUtc}/g" ${i}
    sed -i "s/ro.system_ext.build.date=.*/ro.system_ext.build.date=${buildDate}/g" ${i}
    sed -i "s/ro.system_ext.build.date.utc=.*/ro.system_ext.build.date.utc=${buildUtc}/g" ${i}
    sed -i "s/persist.sys.timezone=.*/persist.sys.timezone=Asia\/Shanghai/g" ${i}
    #全局替换device_code
    sed -i "s/$port_device_code/$base_device_code/g" ${i}
    sed -i "s/$port_rom_model/$base_rom_model/g" ${i}
    sed -i "s/$port_product_name/$base_product_name/g" ${i}
    sed -i "s/$port_my_product_type/$base_my_product_type/g" ${i}
    sed -i "s/$port_market_name/$base_market_name/g" ${i}
    sed -i "s/$port_product_device/$base_product_device/g" ${i}
    # 添加build user信息
    sed -i "s/ro.build.user=.*/ro.build.user=${build_user}/g" ${i}
done

#sed -i -e '$a\'$'\n''persist.adb.notify=0' build/portrom/images/system/system/build.prop
#sed -i -e '$a\'$'\n''persist.sys.usb.config=mtp,adb' build/portrom/images/system/system/build.prop
#sed -i -e '$a\'$'\n''persist.sys.disable_rescue=true' build/portrom/images/system/system/build.prop

base_rom_density=$(grep "ro.sf.lcd_density" --include="*.prop" -r build/baserom/images/my_product | head -n 1 | cut -d "=" -f2)
[ -z ${base_rom_density} ] && base_rom_density=480

if grep -q "ro.sf.lcd_density" build/portrom/images/my_product/build.prop ;then
        sed -i "s/ro.sf.lcd_density=.*/ro.sf.lcd_density=${base_rom_density}/g" build/portrom/images/my_product/build.prop
else
        echo "ro.sf.lcd_density=${base_rom_density}" >> build/portrom/images/my_product/build.prop
    fi

# fix bootloop
cp -rf build/baserom/images/my_product/etc/extension/sys_game_manager_config.json build/portrom/images/my_product/etc/extension/

props=("ro.oplus.display.screenSizeInches.primary" "ro.display.rc.size" "ro.oplus.display.rc.size" "ro.oppo.screen.heteromorphism" "ro.oplus.display.screen.heteromorphism" "ro.oppo.screenhole.positon" "ro.oplus.display.screenhole.positon" "ro.lcd.display.screen.underlightsensor.region" "ro.oplus.lcd.display.screen.underlightsensor.region")

props+=("ro.display.brightness.hbm_xs" "ro.display.brightness.hbm_xs_min" "ro.display.brightness.hbm_xs_max" "ro.oplus.display.brightness.xs" "ro.oplus.display.brightness.ys" "ro.oplus.display.brightness.hbm_ys" "ro.oplus.display.brightness.default_brightness" "ro.oplus.display.brightness.normal_max_brightness" "ro.oplus.display.brightness.max_brightness" "ro.oplus.display.brightness.normal_min_brightness" "ro.oplus.display.brightness.min_light_in_dnm" "ro.oplus.display.brightness.smooth" "ro.display.brightness.brightness.mode" "ro.display.brightness.mode.exp.per_20" "ro.vendor.display.AIRefreshRate.brightness" "ro.oplus.display.dwb.threshold" "ro.oplus.display.colormode.vivid" "ro.oplus.display.colormode.soft" "ro.oplus.display.colormode.cinema" "ro.oplus.display.colormode.colorful" )

for prop in "${props[@]}" ; do
    base_prop_value=$(grep "$prop=" build/baserom/images/my_product/build.prop | cut -d '=' -f2)
    target_prop_value=$(grep "$prop=" build/portrom/images/my_product/build.prop | cut -d '=' -f2)
    if [[ -n $target_prop_value ]];then
        sed -i "s|${prop}=.*|${prop}=${base_prop_value}|g" build/portrom/images/my_product/build.prop
    else
        echo "${prop}=$base_prop_value" >> build/portrom/images/my_product/build.prop
    fi
done

sed -i "s/persist.oplus.software.audio.right_volume_key=.*/persist.oplus.software.audio.right_volume_key=false/g" build/portrom/images/my_product/build.prop
sed -i "s/persist.oplus.software.alertslider.location=.*/persist.oplus.software.alertslider.location=/g" build/portrom/images/my_product/build.prop
sed -i "s/persist.sys.oplus.anim_level=.*/persist.sys.oplus.anim_level=2/g" build/portrom/images/my_product/build.prop

cp -rf build/baserom/images/my_product/app/com.oplus.vulkanLayer build/portrom/images/my_product/app/
cp -rf build/baserom/images/my_product/app/com.oplus.gpudrivers.sm8250.api30 build/portrom/images/my_product/app/


cp -rf  build/baserom/images/my_product/etc/refresh_rate_config.xml build/portrom/images/my_product/etc/refresh_rate_config.xml
cp -rf  build/baserom/images/my_product/non_overlay build/portrom/images/my_product/non_overlay

cp -rf  build/baserom/images/my_product/etc/sys_resolution_switch_config.xml build/portrom/images/my_product/etc/sys_resolution_switch_config.xml

cp -rf build/baserom/images/my_product/etc/permissions/com.oplus.sensor_config.xml build/portrom/images/my_product/etc/permissions/
add_feature "com.android.systemui.support_media_show" build/portrom/images/my_product/etc/extension/com.oplus.app-features.xml

add_feature "oplus.software.support_blockable_animation" build/portrom/images/my_product/etc/extension/com.oplus.oplus-feature.xml

add_feature "oplus.software.support_quick_launchapp" build/portrom/images/my_product/etc/extension/com.oplus.oplus-feature.xml

features=("oplus.software.display.intelligent_color_temperature_support" "oplus.software.display.dual_sensor_support" "oplus.software.display.lock_color_temperature_in_drag_brightness_bar_support" "oplus.software.display.smart_color_temperature_rhythm_health_support" "oplus.software.display.lhdr_only_dimming_support" "oplus.software.display.screen_calibrate_100apl" "oplus.software.display.rgb_ball_support" "oplus.software.display.screen_select" "oplus.software.display.origin_roundcorner_support")

for feature in "${features[@]}" ; do 
    add_feature "$feature" "build/portrom/images/my_product/etc/permissions/oplus.product.display_features.xml"
done

#Virbation feature
add_feature "oplus.software.vibration_intensity_ime" build/portrom/images/my_product/etc/permissions/oplus.feature.android.xml
add_feature "oplus.software.vibration_tripartite_adaptation" build/portrom/images/my_product/etc/permissions/oplus.feature.android.xml
remove_feature "oplus.software.vibrator_qcom_lmvibrator" 
remove_feature "oplus.software.vibrator_richctap" 
remove_feature "oplus.software.vibrator_luxunvibrator" 
remove_feature "oplus.software.haptic_vibrator_v1.support" 
remove_feature "oplus.software.haptic_vibrator_v2.support" 
remove_feature "oplus.hardware.vibrator_oplus_v1" 
remove_feature "oplus.hardware.vibrator_xlinear_type"
remove_feature "oplus.hardware.vibrator_style_switch"

# Disable DPI switch
remove_feature "oplus.software.display.resolution_switch_support"

remove_feature "oplus.software.view.rgbnormalize"
#Remove Wireless charge support
remove_feature "os.charge.settings.wirelesscharge.support" 
remove_feature "oplus.power.onwirelesscharger.support"
remove_feature "com.oplus.battery.wireless.charging.notificate"

#Display Colormode 
add_feature "oplus.software.display.colormode_calibrate_p3_65_support" build/portrom/images/my_product/etc/permissions/oplus.product.feature_multimedia_unique.xml
add_feature "oplus.software.game_engine_vibrator_v1.support" build/portrom/images/my_product/etc/permissions/oplus.product.features_gameeco_common.xml
#Reno 12 Feature 
add_feature 'os.personalization.wallpaper.live.ripple.enable" args="boolean:true' build/portrom/images/my_product/etc/extension/com.oplus.app-features.xml
add_feature "os.personalization.flip.agile_window.enable" build/portrom/images/my_product/etc/extension/com.oplus.app-features.xml
# Oneplus Alert Slider, Needed for RealmeUI
add_feature  "oplus.software.audio.alert_slider" build/portrom/images/my_product/etc/permissions/oplus.product.feature_multimedia_unique.xml

 # Camera
cp -rf  build/baserom/images/my_product/etc/camera/* build/portrom/images/my_product/etc/camera
cp -rf  build/baserom/images/my_product/vendor/etc/* build/portrom/images/my_product/vendor/etc/

rm -rf  build/portrom/images/my_product/priv-app/*
rm -rf  build/portrom/images/my_product/app/OplusCamera
cp -rf build/baserom/images/my_product/priv-app/* build/portrom/images/my_product/priv-app

cp -rf  build/baserom/images/my_product/product_overlay/*  build/portrom/images/my_product/product_overlay/

# bootanimation
cp -rf build/baserom/images/my_product/media/bootanimation/* build/portrom/images/my_product/media/bootanimation/

rm -rf  build/portrom/images/my_product/overlay/*"${port_my_product_type}".apk
for overlay in $(find build/baserom/images/ -type f -name "*${base_my_product_type}*".apk);do
    cp -rf $overlay build/portrom/images/my_product/overlay/
done
baseCarrierConfigOverlay=$(find build/baserom/images/ -type f -name "CarrierConfigOverlay*.apk")
portCarrierConfigOverlay=$(find build/portrom/images/ -type f -name "CarrierConfigOverlay*.apk")
if [ -f "${baseCarrierConfigOverlay}" ] && [ -f "${portCarrierConfigOverlay}" ];then
    blue "正在替换 [CarrierConfigOverlay.apk]" "Replacing [CarrierConfigOverlay.apk]"
    rm -rf ${portCarrierConfigOverlay}
    cp -rf ${baseCarrierConfigOverlay} $(dirname ${portCarrierConfigOverlay})
fi

add_feature "android.hardware.biometrics.face"  build/portrom/images/my_product/etc/permissions/com.oplus.android-features.xml

add_feature "android.hardware.fingerprint" build/portrom/images/my_product/etc/permissions/com.oplus.android-features.xml

add_feature "oplus.software.display.eyeprotect_paper_textre_support" build/portrom/images/my_product/etc/permissions/oplus.product.feature_multimedia_unique.xml


#自定义替换

#Devices/机型代码/overlay 按照镜像的目录结构，可直接替换目标。
if [[ -d "devices/${base_product_device}/overlay" ]]; then
    cp -rf devices/${base_product_device}/overlay/* build/portrom/images/
else
    yellow "devices/${base_product_device}/overlay 未找到" "devices/${base_product_device}/overlay not found" 
fi

for zip in $(find devices/${base_product_device}/ -name "*.zip"); do
    if unzip -l $zip | grep -q "anykernel.sh" ;then
        blue "检查到第三方内核压缩包 $zip [AnyKernel类型]" "Custom Kernel zip $zip detected [Anykernel]"
        if echo $zip | grep -q ".*-KSU" ; then
          unzip $zip -d tmp/anykernel-ksu/ > /dev/null 2>&1
        elif echo $zip | grep -q ".*-NoKSU" ; then
          unzip $zip -d tmp/anykernel-noksu/ > /dev/null 2>&1
        else
          unzip $zip -d tmp/anykernel/ > /dev/null 2>&1
        fi
    fi
done
for anykernel_dir in tmp/anykernel*; do
    if [ -d "$anykernel_dir" ]; then
        blue "开始整合第三方内核进boot.img" "Start integrating custom kernel into boot.img"
        kernel_file=$(find "$anykernel_dir" -name "Image" -exec readlink -f {} +)
        dtb_file=$(find "$anykernel_dir" -name "dtb" -exec readlink -f {} +)
        dtbo_img=$(find "$anykernel_dir" -name "dtbo.img" -exec readlink -f {} +)
        if [[ "$anykernel_dir" == *"-ksu"* ]]; then
            cp $dtbo_img ${work_dir}/devices/$base_product_device/dtbo_ksu.img
            patch_kernel_to_bootimg "$kernel_file" "$dtb_file" "boot_ksu.img"
            blue "生成内核boot_boot_ksu.img完毕" "New boot_ksu.img generated"
        elif [[ "$anykernel_dir" == *"-noksu"* ]]; then
            cp $dtbo_img ${work_dir}/devices/$base_product_device/dtbo_noksu.img
            patch_kernel_to_bootimg "$kernel_file" "$dtb_file" "boot_noksu.img"
            blue "生成内核boot_noksu.img" "New boot_noksu.img generated"
        else
            cp $dtbo_img ${work_dir}/devices/$base_product_device/dtbo_custom.img
            patch_kernel_to_bootimg "$kernel_file" "$dtb_file" "boot_custom.img"
            blue "生成内核boot_custom.img完毕" "New boot_custom.img generated"
        fi
    fi
    rm -rf $anykernel_dir
done

#添加erofs文件系统fstab
if [ ${pack_type} == "EROFS" ];then
    yellow "检查 vendor fstab.qcom是否需要添加erofs挂载点" "Validating whether adding erofs mount points is needed."
    if ! grep -q "erofs" build/portrom/images/vendor/etc/fstab.qcom ; then
               for pname in system odm vendor product mi_ext system_ext; do
                     sed -i "/\/${pname}[[:space:]]\+ext4/{p;s/ext4/erofs/;s/ro,barrier=1,discard/ro/;}" build/portrom/images/vendor/etc/fstab.qcom
                     added_line=$(sed -n "/\/${pname}[[:space:]]\+erofs/p" build/portrom/images/vendor/etc/fstab.qcom)
    
                    if [ -n "$added_line" ]; then
                        yellow "添加$pname" "Adding mount point $pname"
                    else
                        error "添加失败，请检查" "Adding faild, please check."
                        exit 1
                        
                    fi
                done
    fi
fi

# 去除avb校验
blue "去除avb校验" "Disable avb verification."
disable_avb_verify build/portrom/images/

# data 加密
remove_data_encrypt=$(grep "remove_data_encryption" bin/port_config |cut -d '=' -f 2)
if [ ${remove_data_encrypt} = "true" ];then
    blue "去除data加密"
    for fstab in $(find build/portrom/images -type f -name "fstab.*");do
		blue "Target: $fstab"
		sed -i "s/,fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized+wrappedkey_v0//g" $fstab
		sed -i "s/,fileencryption=aes-256-xts:aes-256-cts:v2+emmc_optimized+wrappedkey_v0//g" $fstab
		sed -i "s/,fileencryption=aes-256-xts:aes-256-cts:v2//g" $fstab
		sed -i "s/,metadata_encryption=aes-256-xts:wrappedkey_v0//g" $fstab
		sed -i "s/,fileencryption=aes-256-xts:wrappedkey_v0//g" $fstab
		sed -i "s/,metadata_encryption=aes-256-xts//g" $fstab
		sed -i "s/,fileencryption=aes-256-xts//g" $fstab
        sed -i "s/,fileencryption=ice//g" $fstab
		sed -i "s/fileencryption/encryptable/g" $fstab
	done
fi

for pname in ${port_partition};do
    rm -rf build/portrom/images/${pname}.img
done
echo "${pack_type}">fstype.txt
if [[ $super_extended == true ]];then
    superSize=$(bash bin/getSuperSize.sh "others")
else
superSize=$(bash bin/getSuperSize.sh $base_product_device)
fi

green "Super大小为${superSize}" "Super image size: ${superSize}"
green "开始打包镜像" "Packing super.img"
for pname in ${super_list};do
    if [ -d "build/portrom/images/$pname" ];then
        if [[ "$OSTYPE" == "darwin"* ]];then
            thisSize=$(find build/portrom/images/${pname} | xargs stat -f%z | awk ' {s+=$1} END { print s }' )
        else
            thisSize=$(du -sb build/portrom/images/${pname} |tr -cd 0-9)
        fi
        blue 以[$pack_type]文件系统打包[${pname}.img] "Packing [${pname}.img] with [$pack_type] filesystem"
        python3 bin/fspatch.py build/portrom/images/${pname} build/portrom/images/config/${pname}_fs_config
        python3 bin/contextpatch.py build/portrom/images/${pname} build/portrom/images/config/${pname}_file_contexts
        #sudo perl -pi -e 's/\\@/@/g' build/portrom/images/config/${pname}_file_contexts
        mkfs.erofs -zlz4hc,9 --mount-point ${pname} --fs-config-file build/portrom/images/config/${pname}_fs_config --file-contexts build/portrom/images/config/${pname}_file_contexts build/portrom/images/${pname}.img build/portrom/images/${pname}
        if [ -f "build/portrom/images/${pname}.img" ];then
            green "成功以 [erofs] 文件系统打包 [${pname}.img]" "Packing [${pname}.img] successfully with [erofs] format"
            #rm -rf build/portrom/images/${pname}
        else
            error "以 [${pack_type}] 文件系统打包 [${pname}] 分区失败" "Faield to pack [${pname}]"
            exit 1
        fi
        unset fsType
        unset thisSize
    fi
done
rm fstype.txt

# 打包 super.img
if [[ $is_ab_device = "false" ]];then
    blue "打包A-only机型 super.img" "Packing super.img for A-only device"
    lpargs="-F --output build/portrom/images/super.img --metadata-size 65536 --super-name super --metadata-slots 2 --device super:$superSize --group=qti_dynamic_partitions:$superSize"
    for pname in ${super_list};do
        if [ -f "build/portrom/images/${pname}.img" ];then
            subsize=$(du -sb build/portrom/images/${pname}.img |tr -cd 0-9)
            green "Super 子分区 [$pname] 大小 [$subsize]" "Super sub-partition [$pname] size: [$subsize]"
            args="--partition ${pname}:none:${subsize}:qti_dynamic_partitions --image ${pname}=build/portrom/images/${pname}.img"
            lpargs="$lpargs $args"
            unset subsize
            unset args
        fi
    done
else
blue "打包V-A/B机型 super.img" "Packing super.img for V-AB device"
lpargs="-F --virtual-ab --output build/portrom/images/super.img --metadata-size 65536 --super-name super --metadata-slots 3 --device super:$superSize --group=qti_dynamic_partitions_a:$superSize --group=qti_dynamic_partitions_b:$superSize"
for pname in ${super_list};do
    if [ -f "build/portrom/images/${pname}.img" ];then
        subsize=$(du -sb build/portrom/images/${pname}.img |tr -cd 0-9)
        green "Super 子分区 [$pname] 大小 [$subsize]" "Super sub-partition [$pname] size: [$subsize]"
        args="--partition ${pname}_a:none:${subsize}:qti_dynamic_partitions_a --image ${pname}_a=build/portrom/images/${pname}.img --partition ${pname}_b:none:0:qti_dynamic_partitions_b"
        lpargs="$lpargs $args"
        unset subsize
        unset args
    fi
done
fi

lpmake $lpargs
#echo "lpmake $lpargs"
if [ -f "build/portrom/images/super.img" ];then
    green "成功打包 super.img" "Pakcing super.img done."
else
    error "无法打包 super.img"  "Unable to pack super.img."
    exit 1
fi
if [[ ${port_vendor_brand} == "realme" ]];then
    os_type="RealmeUI"
else
os_type="ColorOS"
fi
rom_version=$(cat build/portrom/images/my_manifest/build.prop | grep "ro.build.display.id=" |  awk 'NR==1' | cut -d "=" -f2 | cut -d "(" -f1)

blue "正在压缩 super.img" "Comprising super.img"
zstd build/portrom/images/super.img -o build/portrom/super.zst

blue "正在生成刷机脚本" "Generating flashing script"

mkdir -p out/${os_type}_${rom_version}/META-INF/com/google/android/   
mkdir -p out/${os_type}_${rom_version}/firmware-update
cp -rf bin/flash/platform-tools-windows out/${os_type}_${rom_version}/
cp -rf bin/flash/windows_flash_script.bat out/${os_type}_${rom_version}/
cp -rf bin/flash/mac_linux_flash_script.sh out/${os_type}_${rom_version}/
cp -rf bin/flash/zstd out/${os_type}_${rom_version}/META-INF/
mv -f build/portrom/*.zst out/${os_type}_${rom_version}/

cp -rf bin/flash/update-binary out/${os_type}_${rom_version}/META-INF/com/google/android/

if [[ $is_ab_device = "false" ]];then
    mv -f build/baserom/firmware-update/*.img out/${os_type}_${rom_version}/firmware-update
    for fwimg in $(ls out/${os_type}_${rom_version}/firmware-update |cut -d "." -f 1 |grep -vE "super|cust|preloader");do
        if [[ $fwimg == *"xbl"* ]] || [[ $fwimg == *"dtbo"* ]] ;then
            # Warning: If wrong xbl img has been flashed, it will cause phone hard brick, so we just skip it with fastboot mode.
            continue

        elif [[ ${fwimg} == "BTFM" ]];then
            part="bluetooth"
        elif [[ ${fwimg} == "cdt_engineering" ]];then
            part="engineering_cdt"
        elif [[ ${fwimg} == "BTFM" ]];then
            part="bluetooth"
        elif [[ ${fwimg} == "dspso" ]];then
            part="dsp"
        elif [[ ${fwimg} == "keymaster64" ]];then
            part="keymaster"
        elif [[ ${fwimg} == "qupv3fw" ]];then
            part="qupfw"
        elif [[ ${fwimg} == "static_nvbk" ]];then
            part="static_nvbk"
        else
            part=${fwimg}                
        fi

        sed -i "/REM firmware/a \\\platform-tools-windows\\\fastboot.exe flash "${part}" firmware-update\/"${fwimg}".img" out/${os_type}_${rom_version}/windows_flash_script.bat
    done
    sed -i "/_b/d" out/${os_type}_${rom_version}/META-INF/com/google/android/update-binary
    sed -i "s/_a//g" out/${os_type}_${rom_version}/META-INF/com/google/android/update-binary
    sed -i '/^REM SET_ACTION_SLOT_A_BEGIN/,/^REM SET_ACTION_SLOT_A_END/d' out/${os_type}_${rom_version}/windows_flash_script.bat

else
    mv -f build/baserom/images/*.img out/${os_type}_${rom_version}/firmware-update
    for fwimg in $(ls out/${os_type}_${rom_version}/firmware-update |cut -d "." -f 1 |grep -vE "super|cust|preloader");do
        if [[ $fwimg == *"xbl"* ]] || [[ $fwimg == *"dtbo"* ]] || [[ $fwimg == *"reserve"* ]] || [[ $fwimg == *"boot"* ]];then
            rm -rfv out/${os_type}_${rom_version}/firmware-update/*reserve*
            # Warning: If wrong xbl img has been flashed, it will cause phone hard brick, so we just skip it with fastboot mode.
            continue
        elif [[ $fwimg == "mdm_oem_stanvbk" ]] || [[ $fwimg == "spunvm" ]] ;then
            sed -i "/REM firmware/a \\\platform-tools-windows\\\fastboot.exe flash "${fwimg}" firmware-update\/"${fwimg}".img" out/${os_type}_${rom_version}/windows_flash_script.bat
        elif [ "$(echo ${fwimg} |grep vbmeta)" != "" ];then
            sed -i "/REM firmware/a \\\platform-tools-windows\\\fastboot.exe --disable-verity --disable-verification flash "${fwimg}"_b firmware-update\/"${fwimg}".img" out/${os_type}_${rom_version}/windows_flash_script.bat
            sed -i "/REM firmware/a \\\platform-tools-windows\\\fastboot.exe --disable-verity --disable-verification flash "${fwimg}"_a firmware-update\/"${fwimg}".img" out/${os_type}_${rom_version}/windows_flash_script.bat
        else
            sed -i "/REM firmware/a \\\platform-tools-windows\\\fastboot.exe flash "${fwimg}"_b firmware-update\/"${fwimg}".img" out/${os_type}_${rom_version}/windows_flash_script.bat
            sed -i "/REM firmware/a \\\platform-tools-windows\\\fastboot.exe flash "${fwimg}"_a firmware-update\/"${fwimg}".img" out/${os_type}_${rom_version}/windows_flash_script.bat
        fi
    done
fi

sed -i "s/device_code/${base_product_device}/g" out/${os_type}_${rom_version}/windows_flash_script.bat
sed -i "s/device_code/${base_product_device}/g" out/${os_type}_${rom_version}/META-INF/com/google/android/update-binary

sed -i "s/portversion/${port_rom_version}/g" out/${os_type}_${rom_version}/META-INF/com/google/android/update-binary
sed -i "s/baseversion/${base_rom_version}/g" out/${os_type}_${rom_version}/META-INF/com/google/android/update-binary
sed -i "s/andVersion/${port_android_version}/g" out/${os_type}_${rom_version}/META-INF/com/google/android/update-binary
sed -i "s/device_code/${base_product_device}/g" out/${os_type}_${rom_version}/META-INF/com/google/android/update-binary

busybox unix2dos out/${os_type}_${rom_version}/windows_flash_script.bat

 #disable vbmeta
for img in $(find out/${os_type}_${rom_version}/ -type f -name "vbmeta*.img");do
    python3 bin/patch-vbmeta.py ${img} > /dev/null 2>&1
done

ksu_bootimg_file=$(find devices/$base_product_device/ -type f -name "*boot_ksu.img")
nonksu_bootimg_file=$(find devices/$base_product_device/ -type f -name "*boot_noksu.img")
custom_bootimg_file=$(find devices/$base_product_device/ -type f -name "*boot_custom.img")

if [[ -f $nonksu_bootimg_file ]];then
    nonksubootimg=$(basename "$nonksu_bootimg_file")
    mv -f $nonksu_bootimg_file out/${os_type}_${rom_version}/
    mv -f  devices/$base_product_device/dtbo_noksu.img out/${os_type}_${rom_version}/firmware-update/dtbo_noksu.img
    sed -i "s/boot_official.img/$nonksubootimg/g" out/${os_type}_${rom_version}/META-INF/com/google/android/update-binary
    sed -i "s/boot_official.img/$nonksubootimg/g" out/${os_type}_${rom_version}/windows_flash_script.bat
    sed -i "s/boot_official.img/$nonksubootimg/g" out/${os_type}_${rom_version}/mac_linux_flash_script.sh
    sed -i "s/dtbo.img/dtbo_noksu.img/g" out/${os_type}_${rom_version}/META-INF/com/google/android/update-binary
    sed -i "s/dtbo.img/dtbo_noksu.img/g" out/${os_type}_${rom_version}/windows_flash_script.bat
    sed -i "s/dtbo.img/dtbo_noksu.img/g" out/${os_type}_${rom_version}/mac_linux_flash_script.sh
else
    bootimg=$(find build/baserom/ out/${os_type}_${rom_version} -name "boot.img")
    mv -f $bootimg out/${os_type}_${rom_version}/boot_official.img
fi

if [[ -f "$ksu_bootimg_file" ]];then
    ksubootimg=$(basename "$ksu_bootimg_file")
    mv -f $ksu_bootimg_file out/${os_type}_${rom_version}/
    mv -f  devices/$base_product_device/dtbo_ksu.img out/${os_type}_${rom_version}/firmware-update/dtbo_ksu.img
    sed -i "s/boot_tv.img/$ksubootimg/g" out/${os_type}_${rom_version}/META-INF/com/google/android/update-binary
    sed -i "s/boot_tv.img/$ksubootimg/g" out/${os_type}_${rom_version}/windows_flash_script.bat
    sed -i "s/boot_tv.img/$ksubootimg/g" out/${os_type}_${rom_version}/mac_linux_flash_script.sh
    sed -i "s/dtbo_tv.img/dtbo_ksu.img/g" out/${os_type}_${rom_version}/META-INF/com/google/android/update-binary
    sed -i "s/dtbo_tv.img/dtbo_ksu.img/g" out/${os_type}_${rom_version}/windows_flash_script.bat
    sed -i "s/dtbo_tv.img/dtbo_ksu.img/g" out/${os_type}_${rom_version}/mac_linux_flash_script.sh
    
elif [[ -f "$custom_bootimg_file" ]];then
    custombootimg=$(basename "$custom_botimg_file")
    mv -f $custom_botimg_file out/${os_type}_${rom_version}/
    mv -f  devices/$base_product_device/dtbo_custom.img out/${os_type}_${rom_version}/firmware-update/dtbo_custom.img
    sed -i "s/boot_tv.img/$custombootimg/g" out/${os_type}_${rom_version}/META-INF/com/google/android/update-binary
    sed -i "s/boot_tv.img/$custombootimg/g" out/${os_type}_${rom_version}/windows_flash_script.bat
    sed -i "s/boot_tv.img/$custombootimg/g" out/${os_type}_${rom_version}/mac_linux_flash_script.sh
    sed -i "s/dtbo_tv.img/dtbo_custom.img/g" out/${os_type}_${rom_version}/META-INF/com/google/android/update-binary
    sed -i "s/dtbo_tv.img/dtbo_custom.img/g" out/${os_type}_${rom_version}/windows_flash_script.bat
    sed -i "s/dtbo_tv.img/dtbo_custom.img/g" out/${os_type}_${rom_version}/mac_linux_flash_script.sh
    
fi

find out/${os_type}_${rom_version} |xargs touch
pushd out/${os_type}_${rom_version}/ >/dev/null || exit
zip -r ${os_type}_${rom_version}.zip ./*
mv ${os_type}_${rom_version}.zip ../
popd >/dev/null || exit
pack_timestamp=$(date +"%m%d%H%M")
hash=$(md5sum out/${os_type}_${rom_version}.zip |head -c 10)
if [[ $pack_type == "EROFS" ]];then
    pack_type="ROOT_"${pack_type}
fi
mv out/${os_type}_${rom_version}.zip out/${os_type}_${rom_version}_${hash}_${port_rom_model}_${pack_timestamp}_${pack_type}.zip
green "移植完毕" "Porting completed"    
green "输出包路径：" "Output: "
green "$(pwd)/out/${os_type}_${rom_version}_${hash}_${port_rom_model}_${pack_timestamp}_${pack_type}.zip"
