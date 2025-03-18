#!/bin/bash

export LANG=vi_VN.UTF-8
export LANGUAGE=vi_VN:vi
export LC_ALL=vi_VN.UTF-8
export NCURSES_NO_UTF8_ACS=1

# Kiểm tra công cụ cần thiết trên máy của người dùng (đề phòng lỗi không cài đặt)
if ! command -v dialog &> /dev/null; then
    echo "Lỗi: 'dialog' chưa được cài đặt. Vui lòng cài đặt bằng lệnh:"
    echo "      sudo apt-get install dialog"
    exit 1
fi
if ! command -v ps &> /dev/null || ! command -v top &> /dev/null; then
    echo "Lỗi: 'ps' hoặc 'top' chưa được cài đặt. Vui lòng cài đặt bằng lệnh:"
    echo "      sudo apt-get install procps"
    exit 1
fi

# Hàm làm sạch tệp tạm khi thoát
cleanup() {
    rm -f /tmp/process_mgmt_*
}
trap cleanup EXIT INT TERM

# Hàm kiểm tra PID hợp lệ
validate_pid() {
    local pid="$1"
    if [[ ! "$pid" =~ ^[0-9]+$ ]]; then
        dialog --colors --ascii-lines --msgbox "\Z1PID phải là một số nguyên.\Z0" 6 40
        return 1
    fi
    if ! ps -p "$pid" > /dev/null 2>&1; then
        dialog --colors --ascii-lines --msgbox "\Z1Tiến trình với PID $pid không tồn tại.\Z0" 6 50
        return 1
    fi
    return 0
}

# 1. Hiển thị Top 20 tiến trình theo CPU
show_top_processes() {
    local output=$(mktemp /tmp/process_mgmt_XXXXXX)
    top -b -n 1 | head -n 27 > "$output"  
    dialog --colors --ascii-lines --title "\ZbTop 20 tiến trình CPU\Zn" --textbox "$output" 30 100
    rm -f "$output"
    dialog --colors --ascii-lines --msgbox "\Z2Đã hiển thị top 20 tiến trình thành công.\Z0" 6 50
}

# 2. Tìm kiếm tiến trình theo tên
search_process_by_name() {
    local temp_input=$(mktemp /tmp/process_mgmt_XXXXXX)
    dialog --colors --ascii-lines --title "\ZbTìm kiếm tiến trình\Zn" \
           --inputbox "Nhập tên tiến trình cần tìm:" 8 50 2> "$temp_input"
    local proc_name=$(cat "$temp_input")
    rm -f "$temp_input"

    if [ -z "$proc_name" ]; then
        dialog --colors --ascii-lines --msgbox "\Z1Tên tiến trình không được để trống hoặc bạn đã hủy.\Z0" 6 60
        return
    fi

    proc_name=$(echo "$proc_name" | sed 's/[^a-zA-Z0-9_-]//g')
    if [ -z "$proc_name" ]; then
        dialog --colors --ascii-lines --msgbox "\Z1Tên tiến trình chứa ký tự không hợp lệ.\Z0" 6 60
        return
    fi

    local temp_output=$(mktemp /tmp/process_mgmt_XXXXXX)
    ps aux | grep -i "$proc_name" | grep -v grep > "$temp_output"

    if [ -s "$temp_output" ]; then
        dialog --colors --ascii-lines --textbox "$temp_output" 30 100
        dialog --colors --ascii-lines --msgbox "\Z2Đã tìm thấy tiến trình khớp với '$proc_name'.\Z0" 6 60
    else
        dialog --colors --ascii-lines --msgbox "\Z1Không tìm thấy tiến trình nào khớp với '$proc_name'.\Z0" 6 60
    fi
    rm -f "$temp_output"
}

# 3. Hiển thị thông tin chi tiết tiến trình theo PID
show_process_by_pid() {
    local temp_input=$(mktemp /tmp/process_mgmt_XXXXXX)
    dialog --colors --ascii-lines --title "\ZbNhập PID\Zn" \
           --inputbox "Nhập PID của tiến trình:" 8 50 2> "$temp_input"
    local pid=$(cat "$temp_input")
    rm -f "$temp_input"

    if ! validate_pid "$pid"; then
        return
    fi

    local temp_output=$(mktemp /tmp/process_mgmt_XXXXXX)
    {
        echo "Thông tin cơ bản:"
        ps -p "$pid" -o pid,ppid,cmd,%cpu,%mem --no-headers
        echo ""
        echo "Sử dụng tài nguyên (theo top):"
        top -b -n 1 -p "$pid" | tail -n 1
    } > "$temp_output"

    dialog --colors --ascii-lines --textbox "$temp_output" 30 100
    rm -f "$temp_output"
    dialog --colors --ascii-lines --msgbox "\Z2Đã hiển thị thông tin chi tiết PID $pid.\Z0" 6 50
}

# 4. Kết thúc tiến trình theo PID
kill_process_by_pid() {
    local temp_input=$(mktemp /tmp/process_mgmt_XXXXXX)
    dialog --colors --ascii-lines --title "\ZbNhập PID\Zn" \
           --inputbox "Nhập PID của tiến trình cần kết thúc:" 8 50 2> "$temp_input"
    local pid=$(cat "$temp_input")
    rm -f "$temp_input"

    if ! validate_pid "$pid"; then
        return
    fi

    local temp_proc=$(mktemp /tmp/process_mgmt_XXXXXX)
    ps -p "$pid" -o pid,cmd --no-headers > "$temp_proc"
    local cmd_info=$(cat "$temp_proc")
    rm -f "$temp_proc"

    dialog --colors --ascii-lines --yesno "\Zb\ZuCẢNH BÁO:\Zn Bạn sắp kết thúc tiến trình:\n\n$cmd_info\n\nXác nhận?" 10 60
    local confirm=$?

    if [ "$confirm" -eq 0 ]; then
        kill -15 "$pid" 2>/dev/null
        sleep 1
        if ps -p "$pid" > /dev/null 2>&1; then
            kill -9 "$pid" 2>/dev/null
        fi
        if ps -p "$pid" > /dev/null 2>&1; then
            dialog --colors --ascii-lines --msgbox "\Z1Không thể kết thúc tiến trình PID $pid. Kiểm tra quyền.\Z0" 6 60
        else
            dialog --colors --ascii-lines --msgbox "\Z2Tiến trình PID $pid đã được kết thúc.\Z0" 6 60
        fi
    else
        dialog --colors --ascii-lines --msgbox "\Z2Đã hủy thao tác kết thúc tiến trình.\Z0" 6 40
    fi
}

# 5. Thoát chương trình
exit_program() {
    dialog --colors --ascii-lines --yesno "Bạn có chắc chắn muốn thoát chương trình không?" 6 50
    if [ $? -eq 0 ]; then
        dialog --colors --ascii-lines --msgbox "\Z2Đang thoát chương trình...\Z0" 6 40
        clear
        exit 0
    fi
}

# Hàm hiển thị menu chính
main_menu() {
    local choice_file=$(mktemp /tmp/process_mgmt_XXXXXX)
    dialog --colors --ascii-lines --clear \
        --title "\ZbỨng dụng quản lý tiến trình hệ thống\Zn" \
        --menu "\ZuSử dụng số hoặc mũi tên để chọn:\Zn\nChọn một tùy chọn:" 15 60 5 \
        1 "Hiển thị các tiến trình (Top 20 tiến trình theo CPU)" \
        2 "Tìm kiếm tiến trình theo tên" \
        3 "Thông tin chi tiết tiến trình theo PID" \
        4 "Kết thúc tiến trình theo PID" \
        5 "Thoát" \
        2> "$choice_file"

    if [ $? -ne 0 ]; then
        exit_program
    fi

    local CHOICE=$(cat "$choice_file")
    rm -f "$choice_file"

    if [[ ! "$CHOICE" =~ ^[1-5]$ ]]; then
        dialog --colors --ascii-lines --msgbox "\Z1Lựa chọn không hợp lệ. Vui lòng chọn từ 1 đến 5.\Z0" 6 50
        return
    fi

    case "$CHOICE" in
        1) show_top_processes ;;
        2) search_process_by_name ;;
        3) show_process_by_pid ;;
        4) kill_process_by_pid ;;
        5) exit_program ;;
    esac
}

# Vòng lặp chính
while true; do
    main_menu
done