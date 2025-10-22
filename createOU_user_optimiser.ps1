Import-Module ActiveDirectory

#############
## DELETE  ##
#############

function deleteOU {
$DCpath = (Get-ADDomain).DistinguishedName
$rootOU = Read-Host "Déterminer OU racine. Exemple : UBIJURISTE"
$OUpath = "OU=$rootOU,$DCpath"
    # Vérifie si l'OU existe
    if (Get-ADOrganizationalUnit -Filter "Name -eq '$rootOU'" -SearchBase $DCpath -ErrorAction SilentlyContinue) {
        Remove-ADOrganizationalUnit -Identity $OUpath -Recursive -Confirm:$false
        Write-Host "L'OU $rootOU a été supprimée."
    } else {
        Write-Host "L'OU $rootOU n'existe pas, rien à supprimer."
    }
}

function c(){
$DCpath = (Get-ADDomain).DistinguishedName
$rootOU = Read-Host "Déterminer OU racine. Exemple : UBIJURISTE"
$OUpath = "OU=$rootOU,$DCpath"

$CSVPath = Read-Host "Chemin du CSV "
$PathCsv = $CSVPath
$CSVData = Import-CSV -Path $PathCsv -Delimiter ";" -Encoding UTF8
################
## CREATE UO  ##
################

function createOU() {
    # Créer la OU principale si besoin
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$rootOU'" -SearchBase $DCpath -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $rootOU -Path $DCpath -ProtectedFromAccidentalDeletion:$false
        Write-Host "L'OU $rootOU a été créée."
    } else {
        Write-Host "L'OU $rootOU existe déjà."
    }
}


################
## ServiceOU  ##
################

function createServiceOUs {
    # Liste tous les services uniques issus du CSV

    ##Sort-Object -Unique
    #permet de trier une collection d’éléments tout en supprimant les doublons lors du tri
    
    ##Select-Object -ExpandProperty service
    #utilisée pour extraire directement la valeur de la propriété service de chaque objet du tableau
    $Services = $CSVData | Select-Object -ExpandProperty service | Sort-Object -Unique
    foreach ($srv in $Services) {
        $ouPath = "OU=$srv,OU=$rootOU,$DCpath"
        if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$srv'" -SearchBase "OU=$rootOU,$DCpath" -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name $srv -Path "OU=$rootOU,$DCpath" -ProtectedFromAccidentalDeletion:$false
            Write-Host "OU de service $srv créée"
        } else {
            Write-Host "OU de service $srv déjà existante"
        }
    }
}


################
## CREATE GG  ##
################

function createGG {
    $GGs = $CSVData | Select-Object -ExpandProperty service | Sort-Object -Unique
    foreach ($gg in $GGs) {
        $ouPath = "OU=$gg,OU=$rootOU,$DCpath"
        $ggName = "GG_$gg"

        $OUExist = Get-ADOrganizationalUnit -Filter "Name -eq '$gg'" -SearchBase "OU=$rootOU,$DCpath" -ErrorAction SilentlyContinue
        if ($OUExist) {
            $groupExist = Get-ADGroup -Filter "Name -eq '$ggName'" -SearchBase $ouPath -ErrorAction SilentlyContinue
            if (-not $groupExist) {
                New-ADGroup -Name $ggName `
                            -GroupScope Global `
                            -GroupCategory Security `
                            -Path $ouPath
                Write-Host "Groupe créé : $ggName"
            } else {
                Write-Host "Le groupe $ggName existe déjà."
            }
        } else {
            Write-Host "OU $gg non trouvée, le groupe n'a pas été créé."
        }
    }
}


##################
## CREATE User  ##
##################
function createUser() {
$MDPWrite =  Read-Host "Déterminer le MDP par defaut pour les utilisateurs. Exemple : d'emmerde toi xD"
$MDP = $MDPWrite
    foreach ($user in $CSVData) {
        $Nom = $user.nom
        $Prenom = $user.prenom
        $Service = $user.service
        $Fonction = $user.fonction

        # sécurité si champ vide
    if (-not $Nom -or -not $Prenom -or -not $Service) {
        Write-Warning "Donnée manquante pour un utilisateur : $user"
        continue
        }

        $Login = ($Prenom.Substring(0,3) + "." + $Nom).ToLower()
        $Mail = "$Login@srv2025.local"
        $MDP = "P@ssw0rd34"

        $ouPath = "OU=$Service,OU=$rootOU,$DCpath"
        
        # Vérifie que la OU de destination existe
        $targetOU = Get-ADOrganizationalUnit -Filter "Name -eq '$Service'" -SearchBase "OU=$rootOU,$DCpath" -ErrorAction SilentlyContinue
    if (-not $targetOU) {
        Write-Warning "OU cible $ouPath n'existe pas : utilisateur NON créé ($Login)"
        continue
        }

        $userExist = Get-ADUser -Filter "SamAccountName -eq '$Login'" -ErrorAction SilentlyContinue

    if ($userExist) {
        Write-Warning "Utilisateur $Login existe déjà"
        } else {
            New-ADUser -Name "$Prenom $Nom" `
                -DisplayName "$Nom $Prenom" `
                -GivenName $Prenom `
                -Surname $Nom `
                -SamAccountName $Login `
                -UserPrincipalName "$Login@srv2025.local" `
                -EmailAddress $Mail `
                -Title $Fonction `
                -Path $ouPath `
                -AccountPassword (ConvertTo-SecureString $MDP -AsPlainText -Force) `
                -ChangePasswordAtLogon $true `
                -Enabled $true
            Write-Output "Création de l'utilisateur : $Login ($Prenom $Nom)"

            $group = "GG_$Service"
            $grpExist = Get-ADGroup -Filter "Name -eq '$group'" -ErrorAction SilentlyContinue
            if ($grpExist) {
                Add-ADGroupMember -Identity $group -Members $Login -ErrorAction SilentlyContinue
                Write-Host "GG ajouté : $group"
            } else {
                Write-Warning "Le groupe $group n'existe pas : pas d'ajout pour $Login"
            }
        }
    }
}
createOU
createServiceOUs
createGG
createUser
}
#deleteOU
c