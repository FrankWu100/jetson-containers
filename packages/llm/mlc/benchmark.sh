#!/usr/bin/env bash
#
# Llama benchmark with MLC. This script should be invoked from the host and will run 
# the MLC container with the commands to download, quantize, and benchmark the models.
# It will add its collected performance data to jetson-containers/data/benchmarks/mlc.csv 
#
# Set the HUGGINGFACE_TOKEN environment variable to your HuggingFace account token 
# that has been granted access to the Meta-Llama models.  You can run it like this:
#
#    HUGGINGFACE_TOKEN=hf_abc123 ./benchmark.sh meta-llama/Llama-2-7b-hf
#
# If a model is not specified, then the default set of models will be benchmarked.
# See the environment variables below and their defaults for model settings to change.
#
# These are the possible quantization methods that can be set like QUANTIZATION=q4f16_ft
#
#  (MLC 0.1.0) q4f16_0,q4f16_1,q4f16_2,q4f16_ft,q4f16_ft_group,q4f32_0,q4f32_1,q8f16_ft,q8f16_ft_group,q8f16_1
#  (MLC 0.1.1) q4f16_0,q4f16_1,q4f32_1,q4f16_2,q4f16_autoawq,q4f16_ft,e5m2_e5m2_f16
#
set -ex

: "${HUGGINGFACE_TOKEN:=SET_YOUR_HUGGINGFACE_TOKEN}"
: "${MLC_VERSION:=0.1.0}"

: "${QUANTIZATION:=q4f16_ft}"
: "${SKIP_QUANTIZATION:=no}"
: "${USE_SAFETENSORS:=yes}"

: "${MAX_CONTEXT_LEN:=4096}"
: "${MAX_NUM_PROMPTS:=4}"
: "${CONV_TEMPLATE:=llama-2}"
: "${PROMPT:=/data/prompts/completion_16.json}"

: "${OUTPUT_CSV:=/data/benchmarks/mlc.csv}"


function benchmark() 
{
    local model_repo=$1
    local model_name=$(basename $model_repo)
    local model_root="/data/models/mlc/${MLC_VERSION}"
    
    local download_flags="--ignore-patterns='*.pth,*.bin'"

    if [ $USE_SAFETENSORS != "yes" ]; then
		download_flags="--skip-safetensors"
	fi
	
    jetson-containers run \
        -e HUGGINGFACE_TOKEN=${HUGGINGFACE_TOKEN} \
        -e QUANTIZATION=${QUANTIZATION} \
        -e SKIP_QUANTIZATION=${SKIP_QUANTIZATION} \
        -e USE_SAFETENSORS=${USE_SAFETENSORS} \
        -e MAX_CONTEXT_LEN=${MAX_CONTEXT_LEN} \
        -e MAX_NUM_PROMPTS=${MAX_NUM_PROMPTS} \
        -e CONV_TEMPLATE=${CONV_TEMPLATE} \
        -e PROMPT=${PROMPT} \
        -e OUTPUT_CSV=${OUTPUT_CSV} \
        -e MODEL_REPO=${model_repo} \
        -e MODEL_ROOT=${model_root} \
        -v $(jetson-containers root)/packages/llm/mlc:/test \
        -v /mnt/NVME/repos/mlc/mlc-llm-20240415-3403a4e-evian3/python/mlc_llm/model/llama:/usr/local/lib/python3.10/dist-packages/mlc_llm/model/llama \
        -w /test \
        $(autotag mlc:$MLC_VERSION) /bin/bash -c "\
            if [ ! -d \${MODEL_REPO} ]; then \
                MODEL_REPO=\$(huggingface-downloader ${download_flags} \${MODEL_REPO}) ; \
            fi ; \
            bash test.sh $model_name \${MODEL_REPO} "
}
            
   
if [ "$#" -gt 0 ]; then
    benchmark "$@"
    exit 0 
fi

MLC_VERSION="0.1.0" MAX_CONTEXT_LEN=4096 USE_SAFETENSORS=off benchmark "princeton-nlp/Sheared-LLaMA-1.3B"
MLC_VERSION="0.1.0" MAX_CONTEXT_LEN=4096 USE_SAFETENSORS=off benchmark "princeton-nlp/Sheared-LLaMA-2.7B"

MLC_VERSION="0.1.0" MAX_CONTEXT_LEN=4096 benchmark "meta-llama/Llama-2-7b-hf"
MLC_VERSION="0.1.1" MAX_CONTEXT_LEN=8192 benchmark "meta-llama/Meta-Llama-3-8B"

