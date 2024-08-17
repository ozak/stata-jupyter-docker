# docker build -t omerozak/stata-jupyter-docker
# docker run -d -p 8888:8888 omerozak/stata-jupyter-docker
# docker push omerozak/stata-jupyter-docker
# Create docker with stata18-mp and mambaforge

# syntax=docker/dockerfile:1.2

# Parameters
# This could be overridden when building 

ARG STATAVERSION=18
ARG STATATAG=2024-08-07
ARG STATAHUBID=dataeditors


## ================== Define base images =====================

# define the source for Stata
FROM ${STATAHUBID}/stata-mp${STATAVERSION}:${STATATAG} as stata

# Create docker for replication
FROM condaforge/mambaforge

# updates just in case
RUN apt update

# Install Git (if not already installed)
RUN apt-get install -y git

# Create
ENV PROJ_LIB "/opt/conda/share/proj"

# Create environment
RUN conda install mamba -y -c conda-forge --override-channels

# Initialize shell to work with conda
RUN conda init bash

COPY --from=stata /usr/local/stata/ /usr/local/stata/
RUN echo "export PATH=/usr/local/stata:${PATH}" >> /root/.bashrc
ENV PATH "$PATH:/usr/local/stata" 

# To run stata, you need to mount the Stata license file
# by passing it in during runtime: -v stata.lic:/usr/local/stata/stata.lic

# Create and configure the country-stability environment
RUN mamba create -y -n country-stability -c conda-forge --override-channels python=3.11 ipython dask dask-labextension geopandas geoplot georasters ipyparallel jupyter jupyterlab jupyter_contrib_nbextensions mapclassify matplotlib matplotlib-base nodejs numpy nb_conda_kernels pandas pandas-datareader plotly pip pycountry pyproj requests scipy seaborn shapely scikit-learn stata_kernel statsmodels unidecode xlrd \
  && echo 'source activate country-stability' > /home/statauser/.bashrc \
  && mamba run -n country-stability pip install geonamescache linearmodels isounidecode geocoder stargazer jupyter_nbextensions_configurator \
  && mamba run -n country-stability python -m stata_kernel.install \
  && mamba run -n country-stability jupyter lab build --dev-build \
  && wget https://raw.githubusercontent.com/ticoneva/codemirror-legacy-stata/main/stata.js -P $CONDA_PREFIX/envs/country-stability/share/jupyter/lab/staging/node_modules/@codemirror/legacy-modes/mode/ \
  && file="$CONDA_PREFIX/envs/country-stability/share/jupyter/lab/staging/node_modules/@jupyterlab/codemirror/lib/language.js" \
  && squirrel_block="{name: 'Squirrel',displayName: trans.__('Squirrel'),mime: 'text/x-squirrel',extensions: ['nut'],async load() {const m = await import('@codemirror/legacy-modes/mode/clike');return legacy(m.squirrel);}}" \
  && insert_text="{name: 'stata',displayName: trans.__('Stata'),mime: 'text/x-stata',extensions: ['do','ado'],async load() {const m = await import('@codemirror/legacy-modes/mode/stata');return legacy(m.stata);}}" \
  && sed -i "/$squirrel_block/a $insert_text" "$file" \
  && mamba run -n country-stability jupyter lab build --dev-build \
  && mamba run -n country-stability python -m ipykernel install --user --name=conda-env-country-stability-py

# Set environment activation command
RUN echo "mamba activate country-stability"  >> /root/.bashrc

# Expose the port JupyterLab will run on (default is 9000)
EXPOSE 9000

# Start JupyterLab when the container runs
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=9000", "--no-browser", "--allow-root", "--NotebookApp.token='docker'"]
