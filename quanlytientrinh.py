import psutil
import os
import signal
import time

def list_processes():
    """Hiển thị danh sách các tiến trình đang chạy, sắp xếp theo PID."""
    print("\n{:<10} {:<25} {:<15} {:<15} {:<10}".format("PID", "Tên tiến trình", "Trạng thái", "Người dùng", "Ưu tiên"))
    print("-" * 85)
    processes = []
    for proc in psutil.process_iter(['pid', 'name', 'status', 'username', 'nice']):
        try:
            processes.append(proc.info)
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass
    # Sắp xếp theo PID
    processes.sort(key=lambda x: x['pid'])
    for proc in processes:
        print("{:<10} {:<25} {:<15} {:<15} {:<10}".format(
            proc['pid'], proc['name'], proc['status'], proc['username'], proc['nice']
        ))

def process_details(pid):
    """Hiển thị thông tin chi tiết của tiến trình theo PID."""
    try:
        proc = psutil.Process(pid)
        print(f"\nChi tiết tiến trình PID {pid}:")
        print(f"Tên: {proc.name()}")
        print(f"Trạng thái: {proc.status()}")
        print(f"Thời gian khởi chạy: {time.ctime(proc.create_time())}")
        print(f"Số thread: {proc.num_threads()}")
        print(f"Sử dụng CPU: {proc.cpu_percent(interval=1.0)}%")
        print(f"Thời gian CPU đã sử dụng: {proc.cpu_times().user} giây")
        print(f"Sử dụng bộ nhớ: {proc.memory_info().rss / (1024 * 1024):.2f} MB")
    except psutil.NoSuchProcess:
        print(f"Không tìm thấy tiến trình với PID {pid}.")
    except psutil.AccessDenied:
        print(f"Không có quyền truy cập thông tin tiến trình với PID {pid}.")

def manage_process(pid, action):
    """Quản lý tiến trình: kết thúc, tạm dừng, tiếp tục hoặc thay đổi mức độ ưu tiên."""
    try:
        proc = psutil.Process(pid)
        if action == 'terminate':
            proc.terminate()  # Gửi SIGTERM
            print(f"Đã kết thúc tiến trình {pid} (SIGTERM).")
        elif action == 'suspend':
            proc.suspend()  # Gửi SIGSTOP
            print(f"Đã tạm dừng tiến trình {pid} (SIGSTOP).")
        elif action == 'resume':
            proc.resume()  # Gửi SIGCONT
            print(f"Đã tiếp tục tiến trình {pid} (SIGCONT).")
        elif action == 'set_priority':
            priority = int(input("Nhập mức độ ưu tiên mới (-20 đến 19): "))
            proc.nice(priority)
            print(f"Đã đặt mức độ ưu tiên của tiến trình {pid} thành {priority}.")
    except psutil.NoSuchProcess:
        print(f"Không tìm thấy tiến trình với PID {pid}.")
    except psutil.AccessDenied:
        print(f"Không có quyền thực hiện hành động trên tiến trình {pid}.")
    except ValueError:
        print("Mức độ ưu tiên không hợp lệ. Vui lòng nhập số từ -20 đến 19.")

def search_process(search_term):
    """Tìm kiếm tiến trình theo tên hoặc PID."""
    print(f"\nKết quả tìm kiếm cho '{search_term}':")
    print("{:<10} {:<25} {:<15} {:<15} {:<10}".format("PID", "Tên tiến trình", "Trạng thái", "Người dùng", "Ưu tiên"))
    print("-" * 85)
    found = False
    for proc in psutil.process_iter(['pid', 'name', 'status', 'username', 'nice']):
        try:
            if (search_term.isdigit() and int(search_term) == proc.info['pid']) or \
               (search_term.lower() in proc.info['name'].lower()):
                print("{:<10} {:<25} {:<15} {:<15} {:<10}".format(
                    proc.info['pid'], proc.info['name'], proc.info['status'],
                    proc.info['username'], proc.info['nice']
                ))
                found = True
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass
    if not found:
        print(f"Không tìm thấy tiến trình nào khớp với '{search_term}'.")

def main():
    """Chương trình chính với menu tương tác."""
    while True:
        print("\n---- Quản Lý Tiến Trình ----")
        print("1. Liệt kê tất cả tiến trình")
        print("2. Xem chi tiết tiến trình")
        print("3. Quản lý tiến trình")
        print("4. Tìm kiếm tiến trình")
        print("5. Thoát")
        choice = input("Lựa chọn của bạn: ")

        if choice == '1':
            return list_processes()
        elif choice == '2':
            try:
                pid = int(input("Nhập PID của tiến trình: "))
                process_details(pid)
            except ValueError:
                print("PID không hợp lệ. Vui lòng nhập số.")
        elif choice == '3':
            try:
                pid = int(input("Nhập PID của tiến trình: "))
                print("a. Kết thúc tiến trình")
                print("b. Tạm dừng tiến trình")
                print("c. Tiếp tục tiến trình")
                print("d. Thay đổi mức độ ưu tiên")
                action = input("Chọn hành động (a-d): ").lower()
                if action == 'a':
                    manage_process(pid, 'terminate')
                elif action == 'b':
                    manage_process(pid, 'suspend')
                elif action == 'c':
                    manage_process(pid, 'resume')
                elif action == 'd':
                    manage_process(pid, 'set_priority')
                else:
                    print("Hành động không hợp lệ.")
            except ValueError:
                print("PID không hợp lệ. Vui lòng nhập số.")
        elif choice == '4':
            search_term = input("Nhập tên hoặc PID của tiến trình: ")
            search_process(search_term)
        elif choice == '5':
            print("Thoát chương trình.")
            break
        else:
            print("Lựa chọn không hợp lệ, vui lòng thử lại.")

if __name__ == "__main__":
    main()