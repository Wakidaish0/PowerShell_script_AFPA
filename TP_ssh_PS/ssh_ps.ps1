# Charger le module Posh-SSH qui permet de g�rer les connexions SSH/SCP
Import-Module Posh-SSH -ErrorAction Stop

# Configuration des variables pour la connexion SSH et le transfert
$ip = "10.200.200.50"                # Adresse IP de la machine Linux distante
$port = 22                          # Port SSH (22 par d�faut)
$user = "vlan99"                   # Nom d'utilisateur SSH
$plainPassword = "0000"            # Mot de passe SSH (ici en clair, pour simplifier)
$pass = ConvertTo-SecureString $plainPassword -AsPlainText -Force   # Convertir le mot de passe en texte s�curis�
$remotePath = "/home/vlan99/scripts"   # Dossier distant o� le fichier sera copi�
$localFile = "C:\Temp\test.sh"          # Chemin complet du fichier local � transf�rer

# Afficher des informations � l'utilisateur pour confirmation
Write-Host "IP          : $ip"
Write-Host "Utilisateur : $user"
Write-Host "Chemin local: $localFile"
Write-Host "Chemin distant : $remotePath"

# V�rifier que le fichier local existe bien, sinon arr�ter le script avec un message d�erreur
if (-not (Test-Path $localFile)) {
    Write-Host "Erreur : Fichier local introuvable."
    exit
}

# Cr�er un objet d�authentification avec les identifiants
$credential = New-Object System.Management.Automation.PSCredential($user, $pass)

# Etablir une session SSH avec la machine distante
$session = New-SSHSession -ComputerName $ip -Port $port -Credential $credential -AcceptKey
Write-Host "Session SSH �tablie :"
Write-Host $session

# Transf�rer le fichier local vers le dossier distant via SCP
Set-SCPItem -Path $localFile -Destination $remotePath -ComputerName $ip -Port $port -Credential $credential -AcceptKey
Write-Host "Fichier transf�r�"

# R�cup�rer l'ID de session, qui peut �tre stock� dans un tableau ou objet simple selon la version du module
$sessionId = if ($session -is [array]) { $session[0].SessionId } else { $session.SessionId }

# Sur la machine distante, modifier les droits du fichier pour le rendre ex�cutable
$output = Invoke-SSHCommand -SessionId $sessionId -Command "chmod +x $remotePath/$(Split-Path $localFile -Leaf)"
Write-Host "Modification des droits :"
Write-Host $output.Output

# Ex�cuter le script sur la machine distante avec bash
$output = Invoke-SSHCommand -SessionId $sessionId -Command "bash $remotePath/$(Split-Path $localFile -Leaf)"
Write-Host "Sortie du script distant :"
Write-Host $output.Output

# Fermer proprement la session SSH pour lib�rer les ressources
Remove-SSHSession -SessionId $sessionId
