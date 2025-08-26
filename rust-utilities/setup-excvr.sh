#!/usr/bin/env bash
set -e

# Nombre del entorno virtual
VENV_NAME=".venv"

# Crear venv si no existe
if [ ! -d "$VENV_NAME" ]; then
    echo "Creando entorno virtual Python en $VENV_NAME..."
    python3 -m venv $VENV_NAME
else
    echo "Entorno virtual ya existe."
fi

# Activar el venv
source $VENV_NAME/bin/activate

# Actualizar pip y setuptools
echo "Actualizando pip y setuptools..."
pip install --upgrade pip setuptools wheel

# Instalar Jupyter y JupyterLab dentro del venv
echo "Instalando Jupyter..."
pip install notebook jupyterlab jupyter_client ipykernel

# Instalar evcxr_jupyter para Rust
echo "Instalando evcxr_jupyter..."
cargo install evcxr_jupyter

# Registrar kernel Rust dentro del venv
echo "Registrando kernel Rust en el venv..."
evcxr_jupyter --install --sys-prefix

# Registrar kernel Python en el venv (por si acaso)
echo "Registrando kernel Python en el venv..."
python -m ipykernel install --user --name python-$(basename $PWD)-venv --display-name "Python ($(basename $PWD))"

# Listar kernels disponibles
echo "Kernels disponibles:"
jupyter kernelspec list

echo "Setup completado. Recuerda seleccionar en VSCode:"
echo "   - Rust kernel: 'Rust'"
echo "   - Python kernel: 'Python ($(basename $PWD))'"
