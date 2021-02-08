#!/bin/bash


#         # /*---------------------------------------------------------------------------8
#         # |                                                                            |
#         # |                             Playbook Wrapper                               |
#         # |                                                                            |
#         # +------------------------------------4--------------------------------------*/
#
#         export           ANSIBLE_HOST_KEY_CHECKING=False
#         # export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=Yes
#         # export           ANSIBLE_KEEP_REMOTE_FILES=1
#
#
#         ansible-playbook                                                                                                \
#           --inventory   new-hosts.yaml                                                                                  \
#           --user        azureadm                                                                                        \
#           --private-key sshkey                                                                                          \
#           --extra-vars="@sap-parameters.yaml"                                                                           \
#         playbook_00_transition_start_for_sap_install.yaml                                                               \
#         playbook_01_os_base_config.yaml                                                                                 \
#         playbook_02_os_sap_specific_config.yaml                                                                         \
#         playbook_03_bom_processing.yaml                                                                                 \
#         playbook_04a_sap_scs_install.yaml                                                                               \
#         playbook_05a_hana_db_install.yaml                                                                               \
#         playbook_06a_sap_dbload.yaml                                                                                    \
#         playbook_06b_sap_pas_install.yaml                                                                               \
#         playbook_06c_sap_app_install.yaml                                                                               \
#         playbook_06d_sap_web_install.yaml



export           ANSIBLE_HOST_KEY_CHECKING=False

PS3='Please select playbook: '
options=(                           \
        "Base OS Config"            \
        "SAP specific OS Config"    \
        "BOM Processing"            \
        "SCS Install"               \
        "HANA DB Install"           \
        "DB Load"                   \
        "PAS Install"               \
        "APP Install"               \
        "WebDisp Install"           \
        "Pacemaker Setup"           \
        "Pacemaker SCS Setup"       \
        "Pacemaker HANA Setup"      \
        "Quit"                      \
)


select opt in "${options[@]}";
do
        echo "You selected ($REPLY) $opt";
        case $opt in
                "Base OS Config")           playbook=playbook_01_os_base_config.yaml;;
                "SAP specific OS Config")   playbook=playbook_02_os_sap_specific_config.yaml;;
                "BOM Processing")           playbook=playbook_03_bom_processing.yaml;;
                "SCS Install")              playbook=playbook_04a_sap_scs_install.yaml;;
                "HANA DB Install")          playbook=playbook_05a_hana_db_install.yaml;;
                "DB Load")                  playbook=playbook_06a_sap_dbload.yaml;;
                "PAS Install")              playbook=playbook_06b_sap_pas_install.yaml;;
                "APP Install")              playbook=playbook_06c_sap_app_install.yaml;;
                "WebDisp Install")          playbook=playbook_06d_sap_web_install.yaml;;
                "Pacemaker Setup")          playbook=playbook_07a_pacemaker.yaml;;
                "Pacemaker SCS Setup")      playbook=playbook_07b_pacemaker_scs.yaml;;
                "Pacemaker HANA Setup")     playbook=playbook_07c_pacemaker_hana.yaml;;
                "Quit")                     break;;
        esac

        ansible-playbook                                                                                                \
          --inventory   X00_hosts.yml                                                                                   \
          --user        azureadm                                                                                        \
          --private-key sshkey                                                                                          \
          --extra-vars="@sap-parameters.yaml"                                                                           \
          ~/Azure_SAP_Automated_Deployment/sap-hana/deploy/ansible/${playbook}
          break
done