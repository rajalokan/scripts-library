#!/usr/bin/env bash

## Shell Opts ----------------------------------------------------------------
# set -e -u -x

# ## Vars ----------------------------------------------------------------------
# export ANSIBLE_PACKAGE=${ANSIBLE_PACKAGE:-"ansible==2.2.2.0"}
# export ANSIBLE_ROLE_FILE=${ANSIBLE_ROLE_FILE:-"ansible-role-requirements.yml"}
# export DEBIAN_FRONTEND=${DEBIAN_FRONTEND:-"noninteractive"}
#
# # Set the role fetch mode to any option [galaxy, git-clone]
# export ANSIBLE_ROLE_FETCH_MODE=${ANSIBLE_ROLE_FETCH_MODE:-galaxy}

# The vars used to prepare the Ansible runtime venv
PIP_OPTS+=" --upgrade"
PIP_COMMAND="/opt/ansible-runtime/bin/pip"

# virtualenv vars
VIRTUALENV_OPTIONS="--always-copy"

# # This script should be executed from the root directory of the cloned repo
# cd "$(dirname "${0}")/.."
#

# ## Functions -----------------------------------------------------------------

function bootstrap_ansible {
    sudo chown -R ${USER}:${USER} /opt
    source_scripts_library
    GetOSVersion
    # update_and_upgrade
    # install_pip
    create_ansible_runtime_venv
    # ensure_proper_version
    install_ansible
    ensure_ansible_always_runs_from_venv
}

function ensure_ansible_always_runs_from_venv {
    # Ensure that Ansible binaries run from the venv
    pushd /opt/ansible-runtime/bin
      for ansible_bin in $(ls -1 ansible*); do
        sudo ln -sf /opt/ansible-runtime/bin/${ansible_bin} /usr/local/bin/${ansible_bin}
      done
    popd
}

function ensure_proper_version {
    # Ensure we are running the required versions of pip, wheel and setuptools
    ${PIP_COMMAND} install ${PIP_OPTS} ${PIP_INSTALL_OPTIONS} || ${PIP_COMMAND} install ${PIP_OPTS} --isolated ${PIP_INSTALL_OPTIONS}

}

function install_ansible {
    # Install the required packages for ansible
    info_block "Installing ansible"
    $PIP_COMMAND install $PIP_OPTS ansible || $PIP_COMMAND install --isolated $PIP_OPTS ansible
}

function create_ansible_runtime_venv {
    # Figure out the version of python is being used
    PYTHON_EXEC_PATH="$(which python2 || which python)"
    PYTHON_VERSION="$($PYTHON_EXEC_PATH -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"

    # Create a Virtualenv for the Ansible runtime
    if [[ ! -f /opt/ansible-runtime/bin/activate ]]; then
        info_block "Create ansible-runtime virtualenv"
        virtualenv --clear ${VIRTUALENV_OPTIONS} --system-site-packages --python="${PYTHON_EXEC_PATH}" /opt/ansible-runtime
    fi
}

function install_pip {
    # Install pip
    info_block "Install or Upgrade pip"
    get_pip
}

function source_scripts_library {
    info_block "Checking for required libraries." 2> /dev/null ||
        source scripts/scripts-library.sh
}

function update_and_upgrade {
    # Install the base packages
    info_block "Update and install basic system packages"
    case ${os_VENDOR} in
        centos|rhel)
            yum -y install git python2 curl autoconf gcc-c++ \
              python2-devel gcc libffi-devel nc openssl-devel \
              python-pyasn1 pyOpenSSL python-ndg_httpsclient \
              python-netaddr python-prettytable python-crypto PyYAML \
              python-virtualenv
              VIRTUALENV_OPTIONS=""
            ;;
        Ubuntu)
            # sudo apt-get update
            DEBIAN_FRONTEND=noninteractive sudo apt-get -y install \
              git python-all python-dev curl python2.7-dev build-essential \
              libssl-dev libffi-dev netcat python-requests python-openssl python-pyasn1 \
              python-netaddr python-prettytable python-crypto python-yaml \
              python-virtualenv
            ;;
    esac

    # NOTE(mhayden): Ubuntu 16.04 needs python-ndg-httpsclient for SSL SNI support.
    #                This package is not needed in Ubuntu 14.04 and isn't available
    #                there as a package.
    if [[ "${os_VENDOR}" == 'Ubuntu' ]] && [[ "${os_RELEASE}" == '16.04' ]]; then
      DEBIAN_FRONTEND=noninteractive sudo apt-get -y install python-ndg-httpsclient
    fi
}




# ## Main ----------------------------------------------------------------------
#
# # Set the variable to the role file to be the absolute path
# ANSIBLE_ROLE_FILE="$(readlink -f "${ANSIBLE_ROLE_FILE}")"
# OSA_INVENTORY_PATH="$(readlink -f playbooks/inventory)"
#


# echo $(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
#
# # # Create openstack ansible wrapper tool
# # sudo bash -c "cat << EOF > /usr/local/bin/okan-ansible
# # #!/usr/bin/env bash
# #
# # export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"
# #
# # function info() {
# #     if [ "\${ANSIBLE_NOCOLOR:-0}" -eq "1" ]; then
# #       echo -e "\${@}"
# #     else
# #       echo -e "\e[0;35m\${@}\e[0m"
# #     fi
# # }
# #
# # # Figure out which Ansible binary was executed
# # RUN_CMD=\$(basename \${0})
# #
# # # Execute the Ansible command.
# # if [ "\${RUN_CMD}" == "okan-ansible" ] || [ "\${RUN_CMD}" == "ansible-playbook" ]; then
# #   /opt/ansible-runtime/bin/ansible-playbook "\${@}" \${VAR1}
# # else
# #   /opt/ansible-runtime/bin/\${RUN_CMD} "\${@}"
# # fi
# # EOF"
#
# # Update dependent roles
# PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# if [ -f "${PROJECT_DIR}/${ANSIBLE_ROLE_FILE}" ]; then
#   if [[ "${ANSIBLE_ROLE_FETCH_MODE}" == 'galaxy' ]];then
#     # Pull all required roles.
#     ansible-galaxy install --role-file="${PROJECT_DIR}/${ANSIBLE_ROLE_FILE}" \
#                            --force
#   elif [[ "${ANSIBLE_ROLE_FETCH_MODE}" == 'git-clone' ]];then
#     pushd tests
#       ansible-playbook get-ansible-role-requirements.yml \
#                        -i ${OSA_CLONE_DIR}/tests/test-inventory.ini \
#                        -e role_file="${PROJECT_DIR}/${ANSIBLE_ROLE_FILE}"
#     popd
#   else
#     echo "Please set the ANSIBLE_ROLE_FETCH_MODE to either of the following options ['galaxy', 'git-clone']"
#     exit 99
#   fi
# fi

info_block "Bootstraping Ansible" 2> /dev/null ||
    if [[ ! -f /tmp/library.sh ]]; then
        wget https://raw.githubusercontent.com/rajalokan/scripts-library/master/library.sh -O /tmp/library.sh 2> /dev/null
    fi
    source /tmp/library.sh
    info_block "Bootstraping Ansible"

bootstrap_ansible
