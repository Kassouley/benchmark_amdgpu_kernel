import argparse
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

def plot_logarithmic(csv_file, col1, step_x, col2, save_plot=None):
    df = pd.read_csv(csv_file)
    
    if col1 not in df.columns or col2 not in df.columns:
        print(f"Les colonnes spécifiées '{col1}' ou '{col2}' ne sont pas présentes dans le fichier CSV.")
        return
    
    x = df[col1]
    y = df[col2]
    
    if (y <= 0).any():
        print("Les données contiennent des valeurs non positives dans la colonne y, ce qui n'est pas permis pour une échelle logarithmique.")
        return
    
    plt.figure(figsize=(10, 6))
    plt.plot(x, y)
    plt.yscale('log')
    plt.xlabel(col1)
    plt.ylabel(col2)
    plt.title(f'Plot {col1} vs {col2}')
    plt.grid(True, which="both", ls="--")
    
    plt.xticks(np.arange(0, max(x) + 1, step_x))
    if save_plot:
        plt.savefig(save_plot)
    else:
        plt.show()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Trace un plot logarithmique à partir d'un fichier CSV et deux colonnes spécifiées.")
    parser.add_argument("csv_file", type=str, help="Chemin vers le fichier CSV")
    parser.add_argument("axe_x", type=str, help="Nom de la première colonne")
    parser.add_argument("step_x", type=str, help="Step de l'axe X")
    parser.add_argument("axe_y", type=str, help="Nom de la deuxième colonne")
    parser.add_argument("--save_plot", type=str, help="Chemin où enregistrer le plot (optionnel)")
    args = parser.parse_args()

    plot_logarithmic(args.csv_file, args.axe_x, args.step_x, args.axe_y, args.save_plot)
