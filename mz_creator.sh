#!/bin/bash
DT_TOKEN="xxx"
DT_ENVIRONMENT="xxx12345.live.dynatrace.com"
WORKLOADS=`cat $2`
if [ "$1" = "delete" ] || [ "$1" = "create-mz" ] || [ "$1" = "create-mz-ap" ]; then
    ACTION=$1
else
    echo "Unsuported action, please choose either 'create', 'delete' or 'alert-profile'."
    exit 1
fi
# if [ "$1" = "alert-profile" ] && [ "$2" != "" ]; then
#     echo "Option alert-profile should have no exta arguments."
#     echo "Ignoring input file \"$2\", alert profile will be created based on managament zones present on the cluster."
#     echo ""
# fi
if [ "$ACTION" = "create-mz" ]; then
    for option in $WORKLOADS; do
        PAYLOAD=$(cat << EOF
        {
            "name": "$option",
            "description": null,
            "rules": [
            {
                "type": "CLOUD_APPLICATION",
                "enabled": true,
                "propagationTypes": [],
                "conditions": [
                {
                    "key": {
                    "attribute": "CLOUD_APPLICATION_NAME",
                    "type": "STATIC"
                    },
                    "comparisonInfo": {
                    "type": "STRING",
                    "operator": "EQUALS",
                    "value": "$option",
                    "negate": false,
                    "caseSensitive": true
                    }
                }
                ]
            },
            {
                "type": "PROCESS_GROUP",
                "enabled": true,
                "propagationTypes": [
                "PROCESS_GROUP_TO_HOST",
                "PROCESS_GROUP_TO_SERVICE"
                ],
                "conditions": [
                {
                    "key": {
                    "attribute": "PROCESS_GROUP_TAGS",
                    "type": "STATIC"
                    },
                    "comparisonInfo": {
                    "type": "TAG",
                    "operator": "EQUALS",
                    "value": {
                        "context": "CONTEXTLESS",
                        "key": "iFood Service",
                        "value": "$option"
                    },
                    "negate": false
                    }
                }
                ]
            }
            ],
            "dimensionalRules": [
            {
                "enabled": true,
                "appliesTo": "METRIC",
                "conditions": [
                {
                    "conditionType": "DIMENSION",
                    "ruleMatcher": "EQUALS",
                    "key": "k8s.workload.name",
                    "value": "$option"
                }
                ]
            }
            ],
            "entitySelectorBasedRules": []
        }
EOF
        )
        echo ""
        echo "Creating MZ: $option"
        curl -X POST "https://$DT_ENVIRONMENT/api/config/v1/managementZones" -H  "accept: application/json; charset=utf-8" -H "Authorization: Api-Token $DT_TOKEN" -H  "Content-Type: application/json; charset=utf-8" -d "$PAYLOAD"
    done
fi
if [ "$ACTION" = "create-mz-ap" ]; then
    for option in $WORKLOADS; do
        PAYLOAD=$(cat << EOF
{
    "name": "$option",
    "description": null,
    "rules": [
    {
        "type": "CLOUD_APPLICATION",
        "enabled": true,
        "propagationTypes": [],
        "conditions": [
        {
            "key": {
            "attribute": "CLOUD_APPLICATION_NAME",
            "type": "STATIC"
            },
            "comparisonInfo": {
            "type": "STRING",
            "operator": "EQUALS",
            "value": "$option",
            "negate": false,
            "caseSensitive": true
            }
        }
        ]
    },
    {
        "type": "PROCESS_GROUP",
        "enabled": true,
        "propagationTypes": [
        "PROCESS_GROUP_TO_HOST",
        "PROCESS_GROUP_TO_SERVICE"
        ],
        "conditions": [
        {
            "key": {
            "attribute": "PROCESS_GROUP_TAGS",
            "type": "STATIC"
            },
            "comparisonInfo": {
            "type": "TAG",
            "operator": "EQUALS",
            "value": {
                "context": "CONTEXTLESS",
                "key": "iFood Service",
                "value": "$option"
            },
            "negate": false
            }
        }
        ]
    }
    ],
    "dimensionalRules": [
    {
        "enabled": true,
        "appliesTo": "METRIC",
        "conditions": [
        {
            "conditionType": "DIMENSION",
            "ruleMatcher": "EQUALS",
            "key": "k8s.workload.name",
            "value": "$option"
        }
        ]
    }
    ],
    "entitySelectorBasedRules": []
}
EOF
        )
        echo ""
        echo "Creating MZ: $option"
        mz_creation_result=$(curl -X POST "https://$DT_ENVIRONMENT/api/config/v1/managementZones" -H  "accept: application/json; charset=utf-8" -H "Authorization: Api-Token $DT_TOKEN" -H  "Content-Type: application/json; charset=utf-8" -d "$PAYLOAD")
        mz_id=$(echo $mz_creation_result | jq .id)
        mz_id=$(echo ${mz_id//\"/""})
        echo ""
        echo "Creating Alerting Profile: $option"
        PAYLOAD2=$(cat << EOF
[{
"summary": "$option",
"author": "Dynatrace POC",
"scope": "environment",
"schemaId": "builtin:alerting.profile",
"schemaVersion": "8",
"value": {
    "name": "$option",
    "managementZone": "$mz_id",
    "severityRules": [
    {
        "severityLevel": "PERFORMANCE",
        "delayInMinutes": 0,
        "tagFilterIncludeMode": "NONE"
    },
    {
        "severityLevel": "MONITORING_UNAVAILABLE",
        "delayInMinutes": 0,
        "tagFilterIncludeMode": "NONE"
    },
    {
        "severityLevel": "ERRORS",
        "delayInMinutes": 0,
        "tagFilterIncludeMode": "NONE"
    },
    {
        "severityLevel": "RESOURCE_CONTENTION",
        "delayInMinutes": 0,
        "tagFilterIncludeMode": "NONE"
    },
    {
        "severityLevel": "CUSTOM_ALERT",
        "delayInMinutes": 0,
        "tagFilterIncludeMode": "NONE"
    },
    {
        "severityLevel": "AVAILABILITY",
        "delayInMinutes": 0,
        "tagFilterIncludeMode": "NONE"
    }
    ],
    "eventFilters": []
}
}]
EOF
        )
        curl -X POST "https://$DT_ENVIRONMENT/api/v2/settings/objects?validateOnly=false" -H  "accept: application/json; charset=utf-8" -H "Authorization: Api-Token $DT_TOKEN" -H  "Content-Type: application/json; charset=utf-8" -d "$PAYLOAD2"
    done
fi
# if [ "$ACTION" = "alert-profile" ]; then
#     mz_json=$(curl -X GET "https://$DT_ENVIRONMENT/api/config/v1/managementZones" -H  "accept: application/json; charset=utf-8" -H  "Authorization: Api-Token $DT_TOKEN")
#     mz_json_no_quotes=$(echo ${mz_json//\"/""})
#     declare -a workloads_array=($(echo $mz_json | jq ".values[].name"))
#     declare -a workloads_id_array=($(echo $mz_json | jq ".values[].id"))
    
#     for mz in ${workloads_array[@]}; do
#         mz_id=""
#         i=0
#         for item in ${workloads_array[@]}; do
#             if [ "$item" = "$mz" ]; then
#                 mz_id=${workloads_id_array[$i]}
#                 echo $mz_id
#                 break
#             else
#                 i=$(($i+1))
#             fi
#         done
#             PAYLOAD=$(cat << EOF
#         {
#     "summary": "$mz",
#     "author": "Dynatrace POC",
#     "scope": "environment",
#     "schemaId": "builtin:alerting.profile",
#     "schemaVersion": "8",
#     "value": {
#       "name": "$mz",
#       "managementZone": "$mz_id",
#       "severityRules": [
#         {
#           "severityLevel": "PERFORMANCE",
#           "delayInMinutes": 0,
#           "tagFilterIncludeMode": "NONE"
#         },
#         {
#           "severityLevel": "MONITORING_UNAVAILABLE",
#           "delayInMinutes": 0,
#           "tagFilterIncludeMode": "NONE"
#         },
#         {
#           "severityLevel": "ERRORS",
#           "delayInMinutes": 0,
#           "tagFilterIncludeMode": "NONE"
#         },
#         {
#           "severityLevel": "RESOURCE_CONTENTION",
#           "delayInMinutes": 0,
#           "tagFilterIncludeMode": "NONE"
#         },
#         {
#           "severityLevel": "CUSTOM_ALERT",
#           "delayInMinutes": 0,
#           "tagFilterIncludeMode": "NONE"
#         },
#         {
#           "severityLevel": "AVAILABILITY",
#           "delayInMinutes": 0,
#           "tagFilterIncludeMode": "NONE"
#         }
#       ],
#       "eventFilters": []
#     }
#   }
# EOF
#         )
#         echo ""
#         echo "Creating Alerting Profile: $mz"
#         #curl -X POST "https://$DT_ENVIRONMENT/api/v2/settings/objects?validateOnly=false" -H  "accept: application/json; charset=utf-8" -H "Authorization: Api-Token $DT_TOKEN" -H  "Content-Type: application/json; charset=utf-8" -d "$PAYLOAD"
#     done
#     for option in $WORKLOADS; do
#         PAYLOAD=$(cat << EOF
#         {
#     "summary": "$OPTION",
#     "author": "Dynatrace POC",
#     "scope": "environment",
#     "schemaId": "builtin:alerting.profile",
#     "schemaVersion": "8",
#     "value": {
#       "name": "$OPTION",
#       "managementZone": "1681837600211418432",
#       "severityRules": [
#         {
#           "severityLevel": "PERFORMANCE",
#           "delayInMinutes": 0,
#           "tagFilterIncludeMode": "NONE"
#         },
#         {
#           "severityLevel": "MONITORING_UNAVAILABLE",
#           "delayInMinutes": 0,
#           "tagFilterIncludeMode": "NONE"
#         },
#         {
#           "severityLevel": "ERRORS",
#           "delayInMinutes": 0,
#           "tagFilterIncludeMode": "NONE"
#         },
#         {
#           "severityLevel": "RESOURCE_CONTENTION",
#           "delayInMinutes": 0,
#           "tagFilterIncludeMode": "NONE"
#         },
#         {
#           "severityLevel": "CUSTOM_ALERT",
#           "delayInMinutes": 0,
#           "tagFilterIncludeMode": "NONE"
#         },
#         {
#           "severityLevel": "AVAILABILITY",
#           "delayInMinutes": 0,
#           "tagFilterIncludeMode": "NONE"
#         }
#       ],
#       "eventFilters": []
#     }
#   }
# EOF
#         )
#         echo ""
#         echo "Creating MZ: $option"
#         curl -X POST "https://pdv45671.live.dynatrace.com/api/config/v1/managementZones" -H  "accept: application/json; charset=utf-8" -H "Authorization: Api-Token $DT_TOKEN" -H  "Content-Type: application/json; charset=utf-8" -d "$PAYLOAD"
#     done
# fi
if [ "$ACTION" = "delete" ]; then
    for option in $WORKLOADS; do
        echo ""
        echo "Deleting MZ: $option"
        DELETE_URL="https://$DT_ENVIRONMENT/api/config/v1/managementZones/$option"
        curl -X DELETE $DELETE_URL -H  "accept: */*" -H "Authorization: Api-Token $DT_TOKEN" -vvv
    done    
fi



