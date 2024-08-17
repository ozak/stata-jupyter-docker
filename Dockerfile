# docker build -t omerozak/stata-jupyter-docker
# docker run -d -p 8888:8888 omerozak/stata-jupyter-docker
# docker push omerozak/stata-jupyter-docker
# Create docker with stata18-mp and mambaforge
FROM dataeditors/stata18-mp:2024-08-07

# updates just in case
#RUN apt-get update
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y  \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y \
  curl \

  # Create
ENV PROJ_LIB "/opt/conda/share/proj"

# Install Miniforge (which includes Mamba)
RUN curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" \
  && bash Miniforge3-$(uname)-$(uname -m).sh -b -p /opt/conda \
  && rm Miniforge3-$(uname)-$(uname -m).sh

# Create environment
RUN conda install mamba -y -c conda-forge --override-channels

# Initialize shell to work with conda
RUN conda init bash

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

# Set user and working directory
USER statauser:stata
WORKDIR /project
VOLUME /project

# Set environment activation command
RUN echo "mamba activate country-stability" >> /home/statauser/.bashrc

# Expose the port JupyterLab will run on (default is 9000)
EXPOSE 9000

# Start JupyterLab when the container runs
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=9000", "--no-browser", "--allow-root", "--NotebookApp.token='docker'"]
