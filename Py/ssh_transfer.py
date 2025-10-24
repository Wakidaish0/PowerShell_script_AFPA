import tkinter as tk
from tkinter import filedialog, messagebox
import paramiko
import os

# =========================
# FONCTION DE TRANSFERT SSH
# =========================
def transfer_and_exec(ip, port, user, password, remote_path, local_file, output_widget):
    """
    Cette fonction réalise :
    - la connexion SSH
    - le transfert du fichier local en SFTP
    - le changement des droits d'exécution sous Linux
    - l'exécution du script bash distant
    - l'affichage du résultat dans l'IHM
    """
    output_widget.delete('1.0', tk.END)  # Nettoyer le widget d'affichage
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())  # Accepte les clés inconnues
    try:
        # Connexion SSH au serveur distant
        output_widget.insert(tk.END, f"Connexion à {ip}:{port}...\n")
        ssh.connect(ip, port=int(port), username=user, password=password)
        output_widget.insert(tk.END, "Connecté. Ouverture SFTP...\n")
        sftp = ssh.open_sftp()

        if not os.path.isfile(local_file):
            output_widget.insert(tk.END, "Fichier local introuvable.\n")
            sftp.close()
            ssh.close()
            return

        # Construction du chemin distant complet
        remote_file = f"{remote_path}/{os.path.basename(local_file)}"
        output_widget.insert(tk.END, f"Transfert du fichier vers {remote_file}...\n")
        sftp.put(local_file, remote_file)
        output_widget.insert(tk.END, "Fichier transféré.\n")
        sftp.close()

        # Changement des droits d'exécution sur le fichier distant
        chmod_cmd = f"chmod +x {remote_file}"
        output_widget.insert(tk.END, "Modification des droits sur le script distant...\n")
        _, stdout, stderr = ssh.exec_command(chmod_cmd)
        err = stderr.read().decode()
        if err:
            output_widget.insert(tk.END, f"Erreur chmod : {err}\n")
        else:
            output_widget.insert(tk.END, "Droits d'exécution modifiés.\n")

        # Exécution du script distant via bash
        exec_cmd = f"bash {remote_file} 2>&1"
        output_widget.insert(tk.END, f"Execution du script distant : {exec_cmd}\n")
        _, stdout, stderr = ssh.exec_command(exec_cmd)
        output = stdout.read().decode()
        errors = stderr.read().decode()

        output_widget.insert(tk.END, "Sortie du script distant :\n")
        output_widget.insert(tk.END, output)
        if errors:
            output_widget.insert(tk.END, "Erreurs :\n"+errors)
        ssh.close()
        output_widget.insert(tk.END, "Session SSH fermée !\n")
    except Exception as e:
        output_widget.insert(tk.END, f"Erreur SSH/SCP/exec : {e}\n")
        try: ssh.close()
        except: pass

# =========================
# INTERFACE UTILISATEUR TKINTER
# =========================
class SSHApp(tk.Tk):
    """
    Cette classe définit la fenêtre principale :
    - champs pour IP, utilisateur, etc.
    - bouton pour sélectionner le fichier
    - bouton lancer le transfert/exécution
    - zone d'affichage pour le log et la sortie
    """
    def __init__(self):
        super().__init__()
        self.title("Transfert & exécution SSH DevOps")
        self.geometry("640x440")
        self.resizable(False, False)
        # --- Entrées utilisateur (devops classiques) ---
        frm = tk.Frame(self, padx=12, pady=12)
        frm.pack()
        row = 0
        tk.Label(frm, text="IP Linux :").grid(row=row, column=0, sticky='e')
        self.ip_entry = tk.Entry(frm, width=24)
        self.ip_entry.insert(0, "10.200.200.50")  # Valeur par défaut
        self.ip_entry.grid(row=row, column=1)
        row += 1
        tk.Label(frm, text="Port SSH :").grid(row=row, column=0, sticky='e')
        self.port_entry = tk.Entry(frm, width=6)
        self.port_entry.insert(0, "22")
        self.port_entry.grid(row=row, column=1, sticky='w')
        row += 1
        tk.Label(frm, text="Utilisateur :").grid(row=row, column=0, sticky='e')
        self.user_entry = tk.Entry(frm, width=16)
        self.user_entry.insert(0, "vlan99")
        self.user_entry.grid(row=row, column=1, sticky='w')
        row += 1
        tk.Label(frm, text="Mot de passe :").grid(row=row, column=0, sticky='e')
        self.pwd_entry = tk.Entry(frm, width=16, show="*")
        self.pwd_entry.insert(0, "0000")
        self.pwd_entry.grid(row=row, column=1, sticky='w')
        row += 1
        tk.Label(frm, text="Dossier distant Linux :").grid(row=row, column=0, sticky='e')
        self.remote_entry = tk.Entry(frm, width=32)
        self.remote_entry.insert(0, "/home/vlan99/scripts")
        self.remote_entry.grid(row=row, column=1, sticky='w')
        row += 1
        tk.Label(frm, text="Fichier local Windows :").grid(row=row, column=0, sticky='e')
        self.file_entry = tk.Entry(frm, width=46)
        self.file_entry.grid(row=row, column=1, sticky='w')
        tk.Button(frm, text="Parcourir", command=self.pick_file).grid(row=row, column=2)
        row += 1
        # --- Bouton de lancement ---
        tk.Button(frm, text="Transférer & exécuter", command=self.launch_transfer).grid(row=row, column=0, columnspan=3, pady=12)
        row += 1
        # --- Zone d'affichage résultat/log ---
        tk.Label(self, text="Log & sortie :").pack()
        self.output_box = tk.Text(self, width=76, height=12, font=("Consolas", 10))
        self.output_box.pack(padx=10, pady=6)
    def pick_file(self):
        fname = filedialog.askopenfilename(filetypes=[("Shell scripts", "*.sh"), ("All files", "*.*")])
        if fname:
            self.file_entry.delete(0, tk.END)
            self.file_entry.insert(0, fname)
    def launch_transfer(self):
        # Lire tous les champs
        ip = self.ip_entry.get().strip()
        port = self.port_entry.get().strip()
        user = self.user_entry.get().strip()
        password = self.pwd_entry.get().strip()
        remote_path = self.remote_entry.get().strip()
        local_file = self.file_entry.get().strip()
        # Lancer le transfert SSH + exécution bash (fonction principale)
        transfer_and_exec(ip, port, user, password, remote_path, local_file, self.output_box)

# =========================
# POINT D'ENTRÉE
# =========================
if __name__ == "__main__":
    # Avant de lancer, il faut installer paramiko : pip install paramiko
    # Tkinter est déjà inclus dans la plupart des versions Python
    app = SSHApp()
    app.mainloop()
