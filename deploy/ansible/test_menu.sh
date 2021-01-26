#!/bin/bash

export           ANSIBLE_HOST_KEY_CHECKING=False

PS3='Please select playbook: '
options=(                           \
        "00 playbook_00_transition_start_for_sap_install_refactor"                  \
        "01 Base OS Config"         \
        "02 SAP specific OS Config" \
        "03 BOM Processing"         \
        "04 SCS Install"            \
        "05 HANA DB Install"        \
        "06 DB Load"                \
        "07 PAS Install"            \
        "08 APP Install"            \
        "09 WebDisp Install"        \
        "Quit"                      \
)


select opt in "${options[@]}";
do
        echo "You selected ($REPLY) $opt";
        case $REPLY in
                1)      playbook=playbook_00_transition_start_for_sap_install_refactor.yaml;;
                2)      playbook=playbook_01_os_base_config.yaml;;
                3)      playbook=playbook_02_os_sap_specific_config.yaml;;
                4)      playbook=playbook_03_bom_processing.yaml;;
                5)      playbook=playbook_04a_sap_scs_install.yaml;;
                6)      playbook=playbook_05a_hana_db_install.yaml;;
                7)      playbook=playbook_06a_sap_dbload.yaml;;
                8)      playbook=playbook_06b_sap_pas_install.yaml;;
                9)      playbook=playbook_06c_sap_app_install.yaml;;
                10)     playbook=playbook_06d_sap_web_install.yaml;;
                11)     break;;
        esac
        ansible-playbook                                                                                                \
          --inventory   new-hosts.yaml                                                                                  \
          --user        azureadm                                                                                        \
          --private-key sshkey                                                                                          \
          --extra-vars="@sap-parameters.yaml"                                                                           \
          ~/Azure_SAP_Automated_Deployment/centiq-sap-hana/deploy/ansible/${playbook}
          break
done