FROM rocm/dev-ubuntu-22.04:5.7.1
ENV HSA_OVERRIDE_GFX_VERSION=8.0.3 \ 
    PYTORCH_ROCM_ARCH=gfx803 \
    ROC_ENABLE_PRE_VEGA=1 \
    USE_CUDA=0 \  
    USE_ROCM=true \ 
    USE_NINJA=1 \
    FORCE_CUDA=1 \ 
    DEBIAN_FRONTEND=noninteractive

## Write the Environment VARSs to global... to compile later with while you use #docker save# or #docker commit#
RUN echo HSA_OVERRIDE_GFX_VERSION=${HSA_OVERRIDE_GFX_VERSION} >> /etc/environment \ 
    echo ROC_ENABLE_PRE_VEGA=${ROC_ENABLE_PRE_VEGA} >> /etc/environment && \
    echo USE_CUDA=${USE_CUDA} >> /etc/environment && \
    echo USE_ROCM=${USE_ROCM} >> /etc/environment && \
    echo USE_NINJA=${USE_NINJA} >> /etc/environment && \
    echo FORCE_CUDA=${FORCE_CUDA} >> /etc/environment && \
    true

## Export the AMD Stuff
RUN export ROC_ENABLE_PRE_VEGA=${ROC_ENABLE_PRE_VEGA} && \
    export HSA_OVERRIDE_GFX_VERSION=${HSA_OVERRIDE_GFX_VERSION} && \
    export USE_CUDA=${USE_CUDA}  && \
    export USE_ROCM=${USE_ROCM}  && \
    export USE_NINJA=${USE_NINJA} && \
    export FORCE_CUDA=${FORCE_CUDA} && \
    true

RUN apt install software-properties-common -y && add-apt-repository ppa:deadsnakes/ppa && apt update && \
    apt install git python3.10 python3.10-venv python3.10-dev -y && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10 && \
    ls -la /usr/bin/python3 && rm /usr/bin/python3 && ln -s python3.10 /usr/bin/python3

# Update System and install python virtual Env
RUN apt-get -y update && \
    apt-get install -y --no-install-recommends virtualenv google-perftools && \
    pip install --upgrade pip wheel && \
    pip install cmake mkl mkl-include && \ 
    true

# git clone PyTorch Version you need for
### PyTorch Version

RUN mkdir /artifacts

ENV PYTORCH_GIT_VERSION="release/2.0"
RUN echo "Checkout ${PYTORCH_GIT_VERSION} " && \  
    git clone --recursive https://github.com/pytorch/pytorch.git -b ${PYTORCH_GIT_VERSION} /pytorch && \
    true

# git clone Torchvision you need
### Torchvision Version
ENV TORCH_GIT_VERSION="release/0.15"
RUN echo "Checkout ${TORCH_GIT_VERSION} " && \ 
    git clone https://github.com/pytorch/vision.git -b ${TORCH_GIT_VERSION} /vision && \
    true

WORKDIR /pytorch

RUN echo "BULDING PYTORCH $(git describe --tags --exact | sed 's/^v//')" && \
    true 

RUN export USE_ROCM=true && USE_ROCM=true python3 setup.py clean && \
    pip install -r requirements.txt && \
    true

RUN python3 tools/amd_build/build_amd.py && \
    true


RUN echo "** BUILDING PYTORCH *** " && \
    export PYTORCH_BUILD_VERSION=$(git describe --tags --exact | sed 's/^v//') && \
    export PYTORCH_BUILD_NUMBER=0 && \
    export USE_ROCM=true && \
    python3 setup.py bdist_wheel && \
    true

RUN mv /pytorch/dist/torch* /artifacts

# Build Vision
WORKDIR /vision

RUN export BUILD_VERSION=$(git describe --tags --exact | sed 's/^v//')  && \
    python3 setup.py bdist_wheel && \
    true


RUN mv /vision/dist/torchvision-* /artifacts

CMD ["/dev/null"]
