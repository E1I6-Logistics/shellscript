"""기존 .bashrc를 보존하며 저장소 경로를 끝에 한 번만 등록한다."""
import argparse
from pathlib import Path
import shlex
import shutil
import time

BEGIN = "# >>> LOGITLE ROBOT ENV >>>"
END = "# <<< LOGITLE ROBOT ENV <<<"


def configure(source, bashrc):
    source, bashrc = Path(source).resolve(), Path(bashrc).expanduser()
    if not source.is_file():
        raise ValueError("환경 파일 없음: " + str(source))
    original = bashrc.read_text() if bashrc.exists() else ""
    before = original
    if BEGIN in original or END in original:
        if original.count(BEGIN) != 1 or original.count(END) != 1:
            raise ValueError(".bashrc 관리 블록이 손상되었습니다. 원본을 수정하지 않았습니다")
        start, end = original.index(BEGIN), original.index(END)
        if end < start:
            raise ValueError(".bashrc 관리 블록 순서가 올바르지 않습니다")
        before = original[:start] + original[end + len(END):]
    # 항상 마지막에 배치한다. 이전 별칭/모델 값보다 이 설정이 우선한다.
    quoted = shlex.quote(str(source))
    block = f"{BEGIN}\nif [ -r {quoted} ]; then\n    source {quoted}\nfi\n{END}\n"
    desired = before.rstrip("\n") + "\n\n" + block
    if desired == original:
        return None
    bashrc.parent.mkdir(parents=True, exist_ok=True)
    backup = None
    if bashrc.exists():
        backup = bashrc.with_name(bashrc.name + ".logitle-backup-" + str(time.time_ns()))
        shutil.copy2(bashrc, backup)
    # 기존 파일의 소유권/권한과 symlink 대상을 유지한다.
    bashrc.write_text(desired)
    return backup


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--bashrc", default=str(Path.home()/".bashrc"))
    args = parser.parse_args()
    try:
        backup = configure(args.source, args.bashrc)
    except (OSError, ValueError) as exc:
        parser.exit(1, "[환경 등록 실패] " + str(exc) + "\n")
    if backup:
        print("기존 설정 백업:", backup)
    print("환경 등록 완료:", args.bashrc)
    print("새 터미널을 열거나 source ~/.bashrc 를 실행하세요. 호스트명 waffle이면 WAF 설정을 적용합니다.")


if __name__ == "__main__":
    main()
