#!/usr/bin/env bash
# 명시한 역할이 우선. AX hostname이 localhost.localdomain이어도 계정으로 구분.
if [ -z "${WAF_ROLE:-}" ]; then
    case "$(hostname)" in
        waffle) export WAF_ROLE=pi ;;
        ax_logistics|ax-logistics) export WAF_ROLE=jetson ;;
        *)
            case "$(id -un)" in
                waffle) export WAF_ROLE=pi ;;
                ax_logistics) export WAF_ROLE=jetson ;;
            esac
            ;;
    esac
fi
