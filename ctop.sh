#!/bin/sh

# ctop - cluster monitoring tool

IN_FILE_NODES=${PWD}/nodes

function max() {
    max=
    while (( "$#" )); do
        if [ -z "$max" ]; then
            max=$1
        else
            [ "$1" -gt "$max" ] && max=$1
        fi
        shift
    done
    return ${max}
}

function min() {
    min=
    while (( "$#" )); do
        if [ -z "$min" ]; then
            min=$1
        else
            [ "$1" -lt "$min" ] && min=$1
        fi
        shift
    done
    return ${min}
}

function repeatchr() {
    chr=$1
    len=$2
    rept=
    while [ ${#rept} -lt $len ]
    do
        rept=${rept}${chr}
    done
    echo ${rept}
}



## For supressing a "Killed" message
exec 2> /dev/null

fixrows()
{
    clear
    COLS=`tput cols`
    LINES=`tput lines`
    echo -ne "$header"
    echo -ne "$footer"
}



while read line
do
    [ "$line" == "" ] && continue
    [[ $line == \#* ]] && continue

    [ -z "${i}" ] && i=0

    col=($line)
    name[${i}]=${col[0]}
    ip[${i}]=${col[1]}

    n=$(( ${#col[@]}-2 ))

    for j in `seq 2 $[ $n + 1 ]`; do
        if [[ ${col[$j]} == np\=* ]]; then
            np[$i]=${col[$j]:3}
        elif [[ ${col[$j]} == c\=* ]]; then
            c[$i]=$(( ${col[$j]:2} + 2 ))
        elif [[ ${col[$j]} == r\=* ]]; then
            r[$i]=$(( ${col[$j]:2} + 3 ))
        elif [[ ${col[$j]} == size\=* ]]; then
            size[${i}]=${col[$j]:5}
        fi
    done

    d[${i}]=$(( ${c[${i}]} + ${size[${i}]} - 1 ))

    (( i++ ))

done < $IN_FILE_NODES

min ${r[@]}; min_r=4
max ${r[@]}; max_r=$?
min ${c[@]}; min_c=3
max ${d[@]}; max_c=$?


es="\033[47;30m"     # emphasis starts
ee="\033[0m"         # emphasis ends

# restore cursor place
cur_r=$(( ${max_r} + 4 ))
cur_c=1
rc="\033[${cur_r};${cur_c}H"

gray="\033[1;30m"   # gray
red="\033[1;31m"    # red
green="\033[1;32m"  # green
yellow="\033[1;33m" # yellow
sky="\033[1;36m"    # sky
blue="\033[1;34m"   # blue
default="\033[0m"   # default

hr=2
hc=3
hsize=$(( ${max_c} - ${min_c} + 1 ))
header="\033[${hr};${hc}H${es}"
header="${header}`printf \"%-$((${hsize}-50))s\" \"   ctop - cluster monitoring tool\"`"
header="${header}`printf \"%50s\" \"SNU-CMS Cluster 2\"`"
header="${header}${ee}${rc}"

mode="CPU USAGE MODE"

fr=$(( ${max_r} + 2 ))
fc=3
fsize=$(( ${max_c} - ${min_c} + 1 ))



loop_ctop() {
    
    for i in `seq 0 $(( ${#name[@]} - 1 ))`; do

        width=$(( ${size[$i]} - ${#name[$i]} - 3 ))

        bar=`repeatchr "#" ${width}`
        grid=`repeatchr "-" ${width}`

        #echo -ne "\033[${r[$i]};${c[$i]}H${name[$i]} [${gray}${grid}${default}]${rc}"

        ## CPU USAGE MODE
        if [ "$mode" == "CPU USAGE MODE" ]; then
            ssh ${ip[$i]} "top -b -d 1 | awk ' /Cpu/ {
                bar=\"${bar}\"
                grid=\"${grid}\"
                
                split(\$0, cpu_status, \":\")
                gsub(/ /, \"\", cpu_status[2])
                gsub(/%[a-z][a-z]/, \"\", cpu_status[2])
                split(cpu_status[2], cpu_each, \",\")

                cpu_us=int(${width}*cpu_each[1]/100)
                cpu_sy=int(${width}*cpu_each[2]/100)
                cpu_ni=int(${width}*cpu_each[3]/100)
                cpu_id=int(${width}*cpu_each[4]/100)
                cpu_wa=int(${width}*cpu_each[5]/100)
                cpu_sum=(cpu_us+cpu_sy+cpu_ni+cpu_wa)

                graph=sprintf(\"${green}%s\",           substr(bar, 1, cpu_us))
                graph=sprintf(\"%s${sky}%s\",    graph, substr(bar, 1, cpu_sy))
                graph=sprintf(\"%s${yellow}%s\", graph, substr(bar, 1, cpu_ni))
                graph=sprintf(\"%s${blue}%s\",   graph, substr(bar, 1, cpu_wa))
                graph=sprintf(\"%s${gray}%s\",   graph, substr(grid, cpu_sum+1))
                graph=sprintf(\"%s${default}\",  graph)


                printf(\"\033[${r[$i]};${c[$i]}H\")
                printf(\"${name[$i]} \")
                printf(\"[%s]\", graph)
                printf(\"${rc}\")
                fflush()
            }

            '" &

        ## MEMORY USAGE MODE
        elif [ "$mode" == "MEMORY USAGE MODE" ]; then

            ssh ${ip[$i]} "free -s 1 | awk '/buffers\/cache:/ {
                bar=\"${bar}\"
                grid=\"${grid}\"

                mem_used=\$3
                mem_free=\$4
                mem_sum=(mem_used+mem_free)
                mem_used_block=${width}*mem_used/mem_sum
                graph=sprintf(\"${red}%s\",            substr(bar, 1, mem_used_block))
                graph=sprintf(\"%s${gray}%s\",  graph, substr(grid, mem_used_block+1))
                graph=sprintf(\"%s${default}\", graph)

                printf(\"\033[${r[$i]};${c[$i]}H\")
                printf(\"${name[$i]} \")
                printf(\"[%s]\", graph)
                printf(\"${rc}\")
                fflush()
            }

            '" &
        fi
        pid[${i}]=$!
    done
        

    while true; do
        date="`date +\"%F %T\"`"
        footer="\033[${fr};${fc}H${es}"
        footer="${footer}`printf \"%-$((${fsize}-50))s\" \"   ${mode}\"`"
        footer="${footer}`printf \"%50s\" \"[q]:Quit  [m]:Mode    ${date}    \"`"
        footer="${footer}${ee}${rc}"
        echo -ne "${header}${footer}"
        sleep 1
    done &
    (( i++ ))
    pid[${i}]=$!
}





############
##  MAIN  ##
############

trap fixrows SIGWINCH
trap '' SIGINT
fixrows
loop_ctop




####################
##  KEY LISTENER  ##
####################

while true; do
    read -n 1 key_press
    if [ "$key_press" == "q" ] || [ "$key_press" == "Q" ]; then
        echo -ne "\b \b"
        kill -9 ${pid[@]}
        break
    elif [ "$key_press" == "m" ] || [ "$key_press" == "M" ]; then
        echo -ne "\b \b"
        kill -9 ${pid[@]}
        pid=
        if [ "$mode" == "CPU USAGE MODE" ]; then mode="MEMORY USAGE MODE"
        elif [ "$mode" == "MEMORY USAGE MODE" ]; then mode="CPU USAGE MODE"
        fi
        loop_ctop
    else
        echo -ne "\b \b"
    fi
done







