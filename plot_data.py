import matplotlib.pyplot as plt
from matplotlib.widgets import Cursor
import re
from datetime import datetime
import numpy as np
import glob
import os

def read_data(filename):
    """Lee los datos de un archivo y retorna timestamps y valores"""
    timestamps = []
    values = []
    
    # Intentar diferentes codificaciones
    for encoding in ['utf-16', 'utf-8', 'latin-1']:
        try:
            with open(filename, 'r', encoding=encoding) as f:
                for line in f:
                    match = re.match(r'(\d{2}:\d{2}:\d{2}\.\d{3})\s+PLOT:\s+\d+,\s+(\d+),', line)
                    if match:
                        time_str = match.group(1)
                        value = int(match.group(2))
                        timestamps.append(time_str)
                        values.append(value)
                if timestamps:  # Si encontramos datos, salimos
                    break
        except UnicodeDecodeError:
            timestamps = []
            values = []
            continue
    
    return timestamps, values

def timestamps_to_seconds(timestamps):
    """Convierte timestamps a segundos relativos desde el inicio"""
    if not timestamps:
        return []
    base_time = datetime.strptime(timestamps[0], '%H:%M:%S.%f')
    time_seconds = []
    for ts in timestamps:
        current_time = datetime.strptime(ts, '%H:%M:%S.%f')
        delta = (current_time - base_time).total_seconds()
        time_seconds.append(delta)
    return time_seconds

def clean_filename(filename):
    """Convierte el nombre del archivo en una etiqueta legible"""
    name = os.path.splitext(os.path.basename(filename))[0]
    # Reemplazar guiones bajos con espacios y capitalizar
    name = name.replace('_', ' ').replace('-', ' ')
    return name.title()

# Encontrar todos los archivos .txt en el directorio actual
txt_files = glob.glob('*.txt')

# Filtrar archivos que contengan datos PLOT válidos
valid_files = []
for file in txt_files:
    print(f"Verificando {file}...")
    timestamps, values = read_data(file)
    if timestamps and values:
        valid_files.append(file)
        print(f"  ✓ {file}: {len(values)} muestras encontradas")
    else:
        print(f"  ✗ {file}: No se encontraron datos válidos")

if not valid_files:
    print("No se encontraron archivos .txt con datos válidos.")
    exit(1)

print(f"\nProcesando {len(valid_files)} archivos...")

# Leer todos los archivos válidos
datasets = {}
for filename in valid_files:
    print(f"Leyendo {filename}...")
    timestamps, values = read_data(filename)
    if timestamps and values:
        time_seconds = timestamps_to_seconds(timestamps)
        datasets[filename] = {
            'timestamps': timestamps,
            'values': values,
            'time_seconds': time_seconds,
            'label': clean_filename(filename)
        }

# Generar colores automáticamente
colors = plt.cm.tab10(np.linspace(0, 1, len(datasets)))
if len(datasets) > 10:
    colors = plt.cm.Set3(np.linspace(0, 1, len(datasets)))

# Crear el gráfico comparativo
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 10))

# Variables para el cursor interactivo
hline1 = None
hline2 = None
text1 = None
text2 = None

# Gráfico 1: Todas las señales
for i, (filename, data) in enumerate(datasets.items()):
    ax1.plot(data['time_seconds'], data['values'], 
             linewidth=0.6, alpha=0.7, label=data['label'], color=colors[i])

ax1.set_xlabel('Tiempo (segundos)')
ax1.set_ylabel('Valor')
ax1.set_title(f'Comparación de señales: {len(datasets)} configuraciones')
ax1.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
ax1.grid(True, alpha=0.3)

# Gráfico 2: Estadísticas de estabilidad (desviación estándar en ventanas)
window_size = 50

for i, (filename, data) in enumerate(datasets.items()):
    values = data['values']
    time_seconds = data['time_seconds']
    if len(values) > window_size:
        std_values = [np.std(values[max(0, j-window_size):j+1]) for j in range(len(values))]
        ax2.plot(time_seconds, std_values, linewidth=0.8, 
                label=f"{data['label']} (ventana={window_size})", color=colors[i])

ax2.set_xlabel('Tiempo (segundos)')
ax2.set_ylabel('Desviación estándar')
ax2.set_title('Estabilidad de la señal (menor desviación = más estable)')
ax2.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
ax2.grid(True, alpha=0.3)

# Función para actualizar la línea y label del cursor
def on_mouse_move(event):
    global hline1, hline2, text1, text2
    
    if event.inaxes in [ax1, ax2]:
        y = event.ydata
        if y is not None:
            # Actualizar línea horizontal y label para ax1
            if event.inaxes == ax1:
                if hline1:
                    hline1.remove()
                if text1:
                    text1.remove()
                hline1 = ax1.axhline(y=y, color='red', linestyle='--', alpha=0.7, linewidth=1)
                text1 = ax1.text(0.02, 0.98, f'Valor: {y:.2f}', 
                               transform=ax1.transAxes, fontsize=10, 
                               verticalalignment='top', 
                               bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.8))
            
            # Actualizar línea horizontal y label para ax2
            elif event.inaxes == ax2:
                if hline2:
                    hline2.remove()
                if text2:
                    text2.remove()
                hline2 = ax2.axhline(y=y, color='red', linestyle='--', alpha=0.7, linewidth=1)
                text2 = ax2.text(0.02, 0.98, f'Desv. Std: {y:.3f}', 
                               transform=ax2.transAxes, fontsize=10, 
                               verticalalignment='top', 
                               bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.8))
            
            fig.canvas.draw_idle()

# Conectar el evento de movimiento del mouse
fig.canvas.mpl_connect('motion_notify_event', on_mouse_move)

plt.tight_layout()
plt.savefig('grafico_comparacion.png', dpi=150, bbox_inches='tight')
plt.show()

# Estadísticas
print("\n" + "="*60)
print("ESTADÍSTICAS DE COMPARACIÓN")
print("="*60)

# Mostrar estadísticas para cada archivo
for filename, data in datasets.items():
    values = data['values']
    time_seconds = data['time_seconds']
    
    print(f"\n{data['label'].upper()}:")
    print(f"  Archivo: {filename}")
    print(f"  Muestras: {len(values)}")
    if time_seconds:
        print(f"  Duración: {time_seconds[-1]:.2f} segundos")
    print(f"  Valor promedio: {np.mean(values):.2f}")
    print(f"  Desviación estándar: {np.std(values):.2f}")
    print(f"  Rango: {min(values)} - {max(values)}")
    print(f"  Variación: {max(values) - min(values)}")

# Comparación de estabilidad
print(f"\nCOMPARACIÓN DE ESTABILIDAD (ordenado de más a menos estable):")
configs = []
for filename, data in datasets.items():
    values = data['values']
    std_dev = np.std(values)
    variation = max(values) - min(values)
    configs.append((data['label'], std_dev, variation))

configs_sorted = sorted(configs, key=lambda x: x[1])
for i, (name, std, var) in enumerate(configs_sorted, 1):
    print(f"  {i}. {name}: σ={std:.2f}, variación={var}")

print(f"\nGráfico guardado como 'grafico_comparacion.png'")
print(f"Total de archivos procesados: {len(datasets)}")
