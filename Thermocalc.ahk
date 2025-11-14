/*
Script: Thermocalc
Συγγραφέας: Tasos
Έτος: 2025
MIT License
Copyright (c) 2025 Tasos
*/
#Requires AutoHotkey v2.0
#SingleInstance Force

; ═══════════════════════════════════════════════════════════
; ΠΡΟΓΡΑΜΜΑ ΔΙΑΧΕΙΡΙΣΗΣ ΚΑΥΣΤΗΡΑ ΠΟΛΥΚΑΤΟΙΚΙΑΣ
; ═══════════════════════════════════════════════════════════

; Μεταβλητές
global Apartments := Map()
global INIFile := ""
global OriginalINIFile := ""
global HeatINIFile := ""

; Δημιουργία GUI
TraySetIcon("Shell32.dll", 44)
global MyGui := Gui("-Resize +MaximizeBox +MinimizeBox", "Thermocalc")
MyGui.SetFont("s10", "Segoe UI")
MyGui.BackColor := "0xF0F0F0"

; Κουμπιά - Αφαίρεση Φόρτωση, προσθήκη "Φόρτωση HEAT_"
MyGui.Add("Button", "x20 y20 w150 h40", "📂 Επιλογή INI").OnEvent("Click", SelectINIFile)
MyGui.Add("Button", "x180 y20 w150 h40", "📥 Φόρτωση HEAT_").OnEvent("Click", LoadHeatINI)
MyGui.Add("Button", "x340 y20 w150 h40", "➕ Νέο Διαμέρισμα").OnEvent("Click", AddNewApartment)
MyGui.Add("Button", "x500 y20 w150 h40", "💾 Αποθήκευση HEAT_").OnEvent("Click", SaveToHeatINI)
MyGui.Add("Button", "x660 y20 w180 h40", "🔥 Μεταφορά Θέρμανσης").OnEvent("Click", TransferHeatingPercent)
MyGui.Add("Button", "x850 y20 w150 h40", "🧮 Υπολογισμός").OnEvent("Click", CalculateTotals)

; Εμφάνιση τρέχοντος αρχείου
MyGui.Add("Text", "x20 y70 w150", "Αρχείο Ανάγνωσης:").SetFont("s9 Bold")
global CurrentFileText := MyGui.Add("Edit", "x170 y67 w830 h30 ReadOnly Background0xE3F2FD")
CurrentFileText.Text := "Δεν έχει επιλεγεί αρχείο"
CurrentFileText.SetFont("s9")

MyGui.Add("Text", "x20 y105 w150", "Αρχείο Εγγραφής:").SetFont("s9 Bold")
global HeatFileText := MyGui.Add("Edit", "x170 y102 w830 h30 ReadOnly Background0xFFF3E0")
HeatFileText.Text := "Δεν έχει δημιουργηθεί"
HeatFileText.SetFont("s9")

; Τίτλος
MyGui.Add("Text", "x20 y145 w800", "═══ ΔΙΑΜΕΡΙΣΜΑΤΑ & ΣΤΟΙΧΕΙΑ ΚΑΥΣΤΗΡΑ ═══").SetFont("s11 Bold")

; ListView
global LV := MyGui.Add("ListView", "x20 y175 w1340 h385 Grid", [
    "Διαμέρισμα", "Ιδιοκτήτης", "Θέρμανση",
    "ei", "fi", "Ώρες Μετρητή (Mi)", "ei × fi", "Πi %"
])

LV.ModifyCol(1, 100)  ; Διαμέρισμα
LV.ModifyCol(2, 250)  ; Ιδιοκτήτης
LV.ModifyCol(3, 90)   ; Θέρμανση
LV.ModifyCol(4, 120)  ; ei
LV.ModifyCol(5, 120)  ; fi
LV.ModifyCol(6, 150)  ; Ώρες Μετρητή
LV.ModifyCol(7, 150)  ; ei × fi
LV.ModifyCol(8, 150)  ; Πi %

LV.OnEvent("DoubleClick", EditApartment)

; Σύνολα
MyGui.Add("GroupBox", "x20 y580 w1340 h120", "📊 ΣΥΝΟΛΑ & ΥΠΟΛΟΓΙΣΜΟΙ")

MyGui.Add("Text", "x40 y610 w150", "Σύνολο ei:")
global TotalEiText := MyGui.Add("Edit", "x190 y607 w120 h25 ReadOnly Center Background0xE8F5E9")
TotalEiText.SetFont("s10 Bold c0x1B5E20")

MyGui.Add("Text", "x330 y610 w150", "Σύνολο fi:")
global TotalFiText := MyGui.Add("Edit", "x480 y607 w120 h25 ReadOnly Center Background0xE3F2FD")
TotalFiText.SetFont("s10 Bold c0x0D47A1")

MyGui.Add("Text", "x620 y610 w180", "Σύνολο Ωρών (ΣMi):")
global TotalHoursText := MyGui.Add("Edit", "x800 y607 w120 h25 ReadOnly Center Background0xFFF3E0")
TotalHoursText.SetFont("s10 Bold c0xE65100")

MyGui.Add("Text", "x940 y610 w150", "Σύνολο (ei × fi):")
global TotalProductText := MyGui.Add("Edit", "x1090 y607 w120 h25 ReadOnly Center Background0xF3E5F5")
TotalProductText.SetFont("s10 Bold c0x6A1B9A")

MyGui.Add("Text", "x40 y650 w250", "Σύνολο Πi%:")
global TotalPiText := MyGui.Add("Edit", "x290 y647 w150 h30 ReadOnly Center Background0xFFCDD2")
TotalPiText.SetFont("s12 Bold c0xC62828")

MyGui.Add("Text", "x460 y655 w400", "⚠️ Σύνολο ei πρέπει να είναι 1.0000").SetFont("s9 cRed")

; Εμφάνιση
MyGui.Show("w1380 h730")

; ═══════════════════════════════════════════════════════════
; ΣΥΝΑΡΤΗΣΕΙΣ
; ═══════════════════════════════════════════════════════════

; Συνάρτηση φυσικής ταξινόμησης
NaturalSort(a, b) {
    ; Εξαγωγή αριθμών και γραμμάτων από τα κλειδιά
    aNum := RegExMatch(a, "\d+") ? RegExReplace(a, "\D+", "") : "0"
    bNum := RegExMatch(b, "\d+") ? RegExReplace(b, "\D+", "") : "0"
    
    aLetter := RegExMatch(a, "[Α-Ωα-ωA-Za-z]+") ? RegExReplace(a, "\d+", "") : ""
    bLetter := RegExMatch(b, "[Α-Ωα-ωA-Za-z]+") ? RegExReplace(b, "\d+", "") : ""
    
    ; Πρώτα σύγκριση γραμμάτων (χρήση StrCompare για strings)
    if (aLetter != bLetter)
        return StrCompare(aLetter, bLetter, "Locale")
    
    ; Μετά σύγκριση αριθμών
    aNumVal := Number(aNum)
    bNumVal := Number(bNum)
    if (aNumVal != bNumVal)
        return (aNumVal < bNumVal) ? -1 : 1
    
    ; Αν είναι ίδια, αλφαβητική σύγκριση
    return StrCompare(a, b, "Locale")
}

SelectINIFile(*) {
    global INIFile, OriginalINIFile, CurrentFileText, HeatFileText
    
    ; Άνοιγμα διαλόγου επιλογής αρχείου
    SelectedFile := FileSelect("3", A_ScriptDir, "Επιλέξτε INI Αρχείο", "INI Files (*.ini)")
    
    if SelectedFile = ""
        return
    
    ; Ενημέρωση μεταβλητών
    OriginalINIFile := SelectedFile
    INIFile := SelectedFile
    
    ; Ενημέρωση GUI
    CurrentFileText.Text := SelectedFile
    
    ; Δημιουργία προτεινόμενου ονόματος HEAT_ αρχείου για εμφάνιση
    SplitPath(SelectedFile, &name, &dir, &ext)
    nameWithoutExt := SubStr(name, 1, -4)
    suggestedHeatName := dir "\HEAT_" nameWithoutExt ".ini"
    
    ; Αυτόματη φόρτωση από το αρχικό αρχείο
    LoadFromOriginalINI()
    
    ; Έλεγχος αν υπάρχει ήδη HEAT_ αρχείο
    if FileExist(suggestedHeatName) {
        result := MsgBox("Βρέθηκε υπάρχον αρχείο HEAT_:`n" suggestedHeatName "`n`nΘέλετε να φορτώσετε τα ei, fi, Hours από αυτό;`n(Αν πατήσετε 'Όχι', θα χρησιμοποιηθούν τα στοιχεία από το αρχικό αρχείο)", "Υπάρχον HEAT_ Αρχείο", 0x24)
        if result = "Yes" {
            INIFile := suggestedHeatName
            HeatFileText.Text := suggestedHeatName
            LoadFromINI()
            MsgBox("Φορτώθηκαν δεδομένα από το HEAT_ αρχείο.", "Πληροφορία", 0x40)
        } else {
            HeatFileText.Text := "Δεν έχει δημιουργηθεί"
        }
    } else {
        HeatFileText.Text := "Δεν έχει δημιουργηθεί"
    }
}

LoadFromOriginalINI(*) {
    global Apartments, LV, OriginalINIFile
    
    if OriginalINIFile = "" {
        MsgBox("Παρακαλώ επιλέξτε πρώτα ένα αρχείο INI!", "Πληροφορία", 0x40)
        return
    }
    
    if !FileExist(OriginalINIFile) {
        MsgBox("Το αρχείο " OriginalINIFile " δεν βρέθηκε!", "Σφάλμα", 0x10)
        return
    }
    
    Apartments.Clear()
    LV.Delete()
    
    sections := IniRead(OriginalINIFile)
    if sections = "ERROR" || sections = "" {
        MsgBox("Το αρχείο INI είναι κενό!", "Σφάλμα", 0x10)
        return
    }
    
    sectionArray := StrSplit(sections, "`n")
    loadedCount := 0
    
    for section in sectionArray {
        section := Trim(section)
        
        if section = "" || section = "Treasury"
            continue
        
        owner := IniRead(OriginalINIFile, section, "Owner", "")
        hasHeating := IniRead(OriginalINIFile, section, "HasHeating", "0")
        
        if owner != "" {
            Apartments[section] := {
                owner: owner,
                hasHeating: (hasHeating = "1") ? 1 : 0,
                ei: 0,
                fi: 0,
                hours: 0
            }
            loadedCount++
        }
    }
    
    UpdateListView()
    CalculateTotals()
    
    MsgBox("Φορτώθηκαν " loadedCount " διαμερίσματα από το αρχικό αρχείο!`n`n✓ Διπλό κλικ σε διαμέρισμα για επεξεργασία`n✓ Κουμπί '➕ Νέο Διαμέρισμα' για προσθήκη`n✓ Χρησιμοποίησε '📥 Φόρτωση HEAT_' για ei, fi, Hours", "Επιτυχία", 0x40)
}

LoadHeatINI(*) {
    global Apartments, INIFile, HeatFileText
    
    ; Διάλογος επιλογής αρχείου HEAT_
    SelectedFile := FileSelect("3", A_ScriptDir, "Επιλέξτε HEAT_ INI Αρχείο", "INI Files (*.ini)")
    
    if SelectedFile = ""
        return
    
    INIFile := SelectedFile
    HeatFileText.Text := SelectedFile
    
    LoadFromINI()
}

LoadFromINI(*) {
    global Apartments, LV, INIFile
    
    if INIFile = "" {
        MsgBox("Παρακαλώ επιλέξτε πρώτα ένα αρχείο INI!", "Πληροφορία", 0x40)
        return
    }
    
    if !FileExist(INIFile) {
        MsgBox("Το αρχείο " INIFile " δεν βρέθηκε!", "Σφάλμα", 0x10)
        return
    }
    
    sections := IniRead(INIFile)
    if sections = "ERROR" || sections = "" {
        MsgBox("Το αρχείο INI είναι κενό!", "Σφάλμα", 0x10)
        return
    }
    
    sectionArray := StrSplit(sections, "`n")
    loadedCount := 0
    
    for section in sectionArray {
        section := Trim(section)
        
        if section = "" || section = "Treasury"
            continue
        
        ; Αν το διαμέρισμα υπάρχει ήδη, ενημέρωσε μόνο τα ei, fi, hours
        if Apartments.Has(section) {
            ei := Number(IniRead(INIFile, section, "ei", "0"))
            fi := Number(IniRead(INIFile, section, "fi", "0"))
            hours := Number(IniRead(INIFile, section, "Hours", "0"))
            
            Apartments[section].ei := ei
            Apartments[section].fi := fi
            Apartments[section].hours := hours
            loadedCount++
        } else {
            ; Αν δεν υπάρχει, δημιούργησέ το
            owner := IniRead(INIFile, section, "Owner", "")
            hasHeating := IniRead(INIFile, section, "HasHeating", "0")
            ei := Number(IniRead(INIFile, section, "ei", "0"))
            fi := Number(IniRead(INIFile, section, "fi", "0"))
            hours := Number(IniRead(INIFile, section, "Hours", "0"))
            
            if owner != "" {
                Apartments[section] := {
                    owner: owner,
                    hasHeating: (hasHeating = "1") ? 1 : 0,
                    ei: ei,
                    fi: fi,
                    hours: hours
                }
                loadedCount++
            }
        }
    }
    
    UpdateListView()
    CalculateTotals()
    
    MsgBox("Φορτώθηκαν δεδομένα για " loadedCount " διαμερίσματα!", "Επιτυχία", 0x40)
}

AddNewApartment(*) {
    global Apartments, MyGui
    
    ; Παράθυρο δημιουργίας νέου διαμερίσματος
    NewGui := Gui("+Owner" MyGui.Hwnd, "Νέο Διαμέρισμα")
    NewGui.SetFont("s10", "Segoe UI")
    NewGui.BackColor := "0xF5F5F5"
    
    NewGui.Add("Text", "x20 y20 w500", "Δημιουργία Νέου Διαμερίσματος").SetFont("s12 Bold c0x0066CC")
    
    NewGui.Add("GroupBox", "x20 y50 w500 h180", "📝 ΣΤΟΙΧΕΙΑ ΔΙΑΜΕΡΙΣΜΑΤΟΣ")
    
    NewGui.Add("Text", "x40 y80 w150", "Κωδικός Διαμερίσματος:")
    EditAptID := NewGui.Add("Edit", "x200 y77 w280 h25", "")
    NewGui.Add("Text", "x40 y105 w450", "(π.χ. Α1, Β2, Γ3, Ισόγειο, κλπ)").SetFont("s8 cGray")
    
    NewGui.Add("Text", "x40 y130 w150", "Ιδιοκτήτης:")
    EditOwner := NewGui.Add("Edit", "x200 y127 w280 h25", "")
    
    NewGui.Add("Text", "x40 y165 w150", "Θέρμανση:")
    EditHasHeating := NewGui.Add("CheckBox", "x200 y162 w250 h25", "Συμμετέχει στη Θέρμανση")
    EditHasHeating.Value := 1  ; Default: ΝΑΙ
    
    NewGui.Add("GroupBox", "x20 y240 w500 h140", "🔢 ΣΥΝΤΕΛΕΣΤΕΣ")
    
    NewGui.Add("Text", "x40 y270 w150", "Συντελεστής ei:")
    EditEi := NewGui.Add("Edit", "x200 y267 w150 h25", "0.000000")
    NewGui.Add("Text", "x360 y270 w120", "(Σύνολο = 1)")
    
    NewGui.Add("Text", "x40 y305 w150", "Συντελεστής fi:")
    EditFi := NewGui.Add("Edit", "x200 y302 w150 h25", "0.0000")
    
    NewGui.Add("Text", "x40 y340 w150", "Ώρες Μετρητή (Mi):")
    EditHours := NewGui.Add("Edit", "x200 y337 w150 h25", "0.00")
    
    BtnCreate := NewGui.Add("Button", "x20 y400 w200 h40", "➕ Δημιουργία")
    BtnCreate.SetFont("s10 Bold")
    BtnCreate.OnEvent("Click", CreateApartment)
    
    BtnCancel := NewGui.Add("Button", "x230 y400 w200 h40", "❌ Ακύρωση")
    BtnCancel.OnEvent("Click", (*) => NewGui.Destroy())
    
    CreateApartment(*) {
        try {
            aptID := Trim(EditAptID.Value)
            owner := Trim(EditOwner.Value)
            hasHeating := EditHasHeating.Value
            ei := Number(EditEi.Value != "" ? EditEi.Value : "0")
            fi := Number(EditFi.Value != "" ? EditFi.Value : "0")
            hours := Number(EditHours.Value != "" ? EditHours.Value : "0")
            
            ; Έλεγχοι
            if aptID = "" {
                MsgBox("Παρακαλώ εισάγετε κωδικό διαμερίσματος!", "Σφάλμα", 0x10)
                return
            }
            
            if Apartments.Has(aptID) {
                MsgBox("Το διαμέρισμα '" aptID "' υπάρχει ήδη!", "Σφάλμα", 0x10)
                return
            }
            
            if owner = "" {
                result := MsgBox("Δεν έχει εισαχθεί ιδιοκτήτης. Συνέχεια;", "Προειδοποίηση", 0x34)
                if result = "No"
                    return
            }
            
            if ei < 0 || fi < 0 || hours < 0 {
                MsgBox("Οι τιμές δεν μπορούν να είναι αρνητικές!", "Σφάλμα", 0x10)
                return
            }
            
            ; Προσθήκη νέου διαμερίσματος
            Apartments[aptID] := {
                owner: owner,
                hasHeating: hasHeating ? 1 : 0,
                ei: ei,
                fi: fi,
                hours: hours
            }
            
            UpdateListView()
            CalculateTotals()
            NewGui.Destroy()
            
            MsgBox("Το διαμέρισμα '" aptID "' δημιουργήθηκε επιτυχώς!`n`n✓ Μην ξεχάσετε να αποθηκεύσετε τις αλλαγές", "Επιτυχία", 0x40)
            
        } catch as e {
            MsgBox("Σφάλμα: " e.Message, "Σφάλμα", 0x10)
        }
    }
    
    NewGui.Show("w540 h470")
}

UpdateListView(*) {
    global Apartments, LV
    
    LV.Delete()
    
    ; Πρώτα υπολογίζουμε το σύνολο ωρών και το ΣΥΝΟΛΟ (ei × fi) ΟΛΩΝ των διαμερισμάτων
    totalHours := 0
    sumEiFi := 0
    
    for apartment, data in Apartments {
        totalHours += data.hours
        sumEiFi += data.ei * data.fi
    }
    
    ; Ταξινόμηση διαμερισμάτων
    sortedKeys := []
    for apartment in Apartments
        sortedKeys.Push(apartment)
    

; Bubble sort με φυσική σύγκριση
    loop sortedKeys.Length {
        i := A_Index
        loop sortedKeys.Length {
            j := A_Index
            if j <= i
                continue
            if NaturalSort(sortedKeys[i], sortedKeys[j]) > 0 {
                temp := sortedKeys[i]
                sortedKeys[i] := sortedKeys[j]
                sortedKeys[j] := temp
            }
        }
    }
    
    ; Εμφάνιση με ταξινομημένη σειρά
    for apartment in sortedKeys {
        data := Apartments[apartment]
        heatingStatus := data.hasHeating ? "ΝΑΙ" : "ΟΧΙ"
        product := data.ei * data.fi
        
        pi := 0
        if totalHours > 0 {
            ; Κανονικός τύπος με ώρες
            pi := (product + (data.hours / totalHours) * (1 - sumEiFi)) * 100
        } else {
            ; Εναλλακτικός τύπος όταν δεν υπάρχουν ώρες: Pi = (ei×fi / Σύνολο(ei×fi)) × 100
            if sumEiFi > 0 {
                pi := (product / sumEiFi) * 100
            } else {
                pi := 0
            }
        }
        
        ; Αποθήκευση Pi στα δεδομένα για μεταγενέστερη χρήση
        data.pi := pi
        
        LV.Add("",
            apartment,
            data.owner,
            heatingStatus,
            Format("{:.6f}", data.ei),
            Format("{:.4f}", data.fi),
            Format("{:.2f}", data.hours),
            Format("{:.8f}", product),
            Format("{:.4f}", pi)
        )
    }
}

EditApartment(LV, Row) {
    global Apartments
    
    if Row = 0
        return
    
    apartment := LV.GetText(Row, 1)
    
    if !Apartments.Has(apartment) {
        MsgBox("Το διαμέρισμα δεν βρέθηκε!", "Σφάλμα", 0x10)
        return
    }
    
    data := Apartments[apartment]
    
    EditGui := Gui("+Owner" MyGui.Hwnd, "Επεξεργασία: " apartment)
    EditGui.SetFont("s10", "Segoe UI")
    EditGui.BackColor := "0xF5F5F5"
    
    EditGui.Add("Text", "x20 y20 w200", "Διαμέρισμα:").SetFont("s10 Bold")
    EditGui.Add("Text", "x230 y20 w300", apartment).SetFont("s11 Bold c0x0066CC")
    
    EditGui.Add("Text", "x20 y50 w200", "Ιδιοκτήτης:")
    EditGui.Add("Text", "x230 y50 w300", data.owner)
    
    EditGui.Add("Text", "x20 y80 w200", "Συμμετέχει στη Θέρμανση:")
    heatingText := data.hasHeating ? "ΝΑΙ ✓" : "ΟΧΙ ✗"
    heatingColor := data.hasHeating ? "c0x006600" : "c0xCC0000"
    EditGui.Add("Text", "x230 y80 w300 " heatingColor, heatingText).SetFont("s10 Bold")
    
    EditGui.Add("GroupBox", "x20 y120 w500 h200", "📝 ΣΤΟΙΧΕΙΑ ΚΑΥΣΤΗΡΑ")
    
    EditGui.Add("Text", "x40 y150 w150", "Συντελεστής ei:")
    EditEi := EditGui.Add("Edit", "x200 y147 w150 h25", Format("{:.6f}", data.ei))
    EditGui.Add("Text", "x360 y150 w150", "(Σύνολο = 1)")
    
    EditGui.Add("Text", "x40 y190 w150", "Συντελεστής fi:")
    EditFi := EditGui.Add("Edit", "x200 y187 w150 h25", Format("{:.4f}", data.fi))
    
    EditGui.Add("Text", "x40 y230 w150", "Ώρες Μετρητή (Mi):")
    EditHours := EditGui.Add("Edit", "x200 y227 w150 h25", Format("{:.2f}", data.hours))
    
    EditGui.Add("GroupBox", "x20 y330 w500 h120", "🧮 ΥΠΟΛΟΓΙΣΜΟΙ")
    
    EditGui.Add("Text", "x40 y360 w150", "ei × fi =")
    PreviewProduct := EditGui.Add("Text", "x200 y360 w150", Format("{:.8f}", data.ei * data.fi))
    PreviewProduct.SetFont("s10 Bold c0x6A1B9A")
    
    EditGui.Add("Text", "x40 y390 w150", "Πi % =")
    PreviewPi := EditGui.Add("Text", "x200 y390 w150", "0.0000")
    PreviewPi.SetFont("s11 Bold c0xC62828")
    
    EditGui.Add("Text", "x40 y420 w450", "Τύπος: Πi = (ei×fi + Mi/ΣMi × (1 - ΣΥΝΟΛΟ(ei×fi))) × 100").SetFont("s8 cGray")
    
    BtnSave := EditGui.Add("Button", "x20 y470 w150 h40", "💾 Αποθήκευση")
    BtnSave.SetFont("s10 Bold")
    BtnSave.OnEvent("Click", SaveEdit)
    
    BtnDelete := EditGui.Add("Button", "x180 y470 w150 h40", "🗑️ Διαγραφή")
    BtnDelete.SetFont("s10 Bold")
    BtnDelete.Opt("Background0xFFCDD2")
    BtnDelete.OnEvent("Click", DeleteApartment)
    
    BtnCancel := EditGui.Add("Button", "x340 y470 w150 h40", "❌ Ακύρωση")
    BtnCancel.OnEvent("Click", (*) => EditGui.Destroy())
    
    EditEi.OnEvent("Change", UpdatePreview)
    EditFi.OnEvent("Change", UpdatePreview)
    EditHours.OnEvent("Change", UpdatePreview)
    
    UpdatePreview(*) {
        try {
            ei := Number(EditEi.Value != "" ? EditEi.Value : "0")
            fi := Number(EditFi.Value != "" ? EditFi.Value : "0")
            hours := Number(EditHours.Value != "" ? EditHours.Value : "0")
            
            PreviewProduct.Text := Format("{:.8f}", ei * fi)
            
            totalHours := 0
            sumEiFi := 0
            
            for apt, d in Apartments {
                if apt = apartment {
                    totalHours += hours
                    sumEiFi += ei * fi
                } else {
                    totalHours += d.hours
                    sumEiFi += d.ei * d.fi
                }
            }
            
            pi := 0
            if totalHours > 0 {
                ; Κανονικός τύπος με ώρες
                pi := (ei * fi + (hours / totalHours) * (1 - sumEiFi)) * 100
            } else {
                ; Εναλλακτικός τύπος όταν δεν υπάρχουν ώρες: Pi = (ei×fi / Σύνολο(ei×fi)) × 100
                if sumEiFi > 0 {
                    pi := (ei * fi / sumEiFi) * 100
                } else {
                    pi := 0
                }
            }
            
            PreviewPi.Text := Format("{:.4f}", pi)
        }
    }
    
    UpdatePreview()

    DeleteApartment(*) {
        result := MsgBox(
            "⚠️ ΠΡΟΣΟΧΗ!`n`n"
            . "Θέλετε να διαγράψετε το διαμέρισμα '" apartment "'?`n`n"
            . "Ιδιοκτήτης: " data.owner "`n`n"
            . "Η ενέργεια αυτή ΔΕΝ μπορεί να αναιρεθεί!",
            "Επιβεβαίωση Διαγραφής",
            0x34
        )
        
        if result = "Yes" {
            Apartments.Delete(apartment)
            UpdateListView()
            CalculateTotals()
            EditGui.Destroy()
            MsgBox("Το διαμέρισμα '" apartment "' διαγράφηκε επιτυχώς!`n`n⚠️ Μην ξεχάσετε να αποθηκεύσετε τις αλλαγές!", "Επιτυχής Διαγραφή", 0x40)
        }
    }
    
    SaveEdit(*) {
        try {
            ei := Number(EditEi.Value != "" ? EditEi.Value : "0")
            fi := Number(EditFi.Value != "" ? EditFi.Value : "0")
            hours := Number(EditHours.Value != "" ? EditHours.Value : "0")
            
            if ei < 0 || fi < 0 || hours < 0 {
                MsgBox("Οι τιμές δεν μπορούν να είναι αρνητικές!", "Σφάλμα", 0x10)
                return
            }
            
            Apartments[apartment].ei := ei
            Apartments[apartment].fi := fi
            Apartments[apartment].hours := hours
            
            UpdateListView()
            CalculateTotals()
            EditGui.Destroy()
            
            MsgBox("Τα στοιχεία ενημερώθηκαν επιτυχώς για το " apartment "!", "Επιτυχία", 0x40)
            
        } catch as e {
            MsgBox("Σφάλμα: " e.Message, "Σφάλμα", 0x10)
        }
    }
    
    EditGui.Show("w560 h540")
}

CalculateTotals(*) {
    global Apartments, TotalEiText, TotalFiText, TotalHoursText, TotalProductText, TotalPiText
    
    totalEi := 0
    totalFi := 0
    totalHours := 0
    sumEiFi := 0
    totalPi := 0
    
    for apartment, data in Apartments {
        totalEi += data.ei
        totalFi += data.fi
        totalHours += data.hours
        sumEiFi += data.ei * data.fi
    }
    
    for apartment, data in Apartments {
        pi := 0
        if totalHours > 0 {
            ; Κανονικός τύπος με ώρες
            pi := (data.ei * data.fi + (data.hours / totalHours) * (1 - sumEiFi)) * 100
        } else {
            ; Εναλλακτικός τύπος όταν δεν υπάρχουν ώρες: Pi = (ei×fi / Σύνολο(ei×fi)) × 100
            if sumEiFi > 0 {
                pi := (data.ei * data.fi / sumEiFi) * 100
            } else {
                pi := 0
            }
        }
        totalPi += pi
    }
    
    TotalEiText.Text := Format("{:.6f}", totalEi)
    TotalFiText.Text := Format("{:.4f}", totalFi)
    TotalHoursText.Text := Format("{:.2f}", totalHours)
    TotalProductText.Text := Format("{:.8f}", sumEiFi)
    TotalPiText.Text := Format("{:.4f}", totalPi) " %"
    
    if Abs(totalEi - 1) > 0.0001 {
        TotalEiText.Opt("Background0xFFCDD2")
    } else {
        TotalEiText.Opt("Background0xC8E6C9")
    }
    
    if Abs(totalPi - 100) > 0.01 {
        TotalPiText.Opt("Background0xFFCDD2")
    } else {
        TotalPiText.Opt("Background0xC8E6C9")
    }
}

SaveToHeatINI(*) {
    global Apartments, OriginalINIFile, HeatFileText
    
    if Apartments.Count = 0 {
        MsgBox("Δεν υπάρχουν διαμερίσματα για αποθήκευση!", "Πληροφορία", 0x40)
        return
    }
    
    ; Προτεινόμενο όνομα αρχείου
    if OriginalINIFile != "" {
        SplitPath(OriginalINIFile, &name, &dir, &ext)
        nameWithoutExt := SubStr(name, 1, -4)
        suggestedName := dir "\HEAT_" nameWithoutExt ".ini"
    } else {
        suggestedName := A_ScriptDir "\HEAT_data.ini"
    }
    
    ; Διάλογος αποθήκευσης αρχείου
    SaveFile := FileSelect("S16", suggestedName, "Αποθήκευση Αρχείου HEAT_", "INI Files (*.ini)")
    
    if SaveFile = ""
        return
    
    ; Προσθήκη .ini αν δεν υπάρχει
    if !InStr(SaveFile, ".ini")
        SaveFile .= ".ini"
    
    ; Διαγραφή παλιού αρχείου αν υπάρχει
    if FileExist(SaveFile) {
        result := MsgBox("Το αρχείο υπάρχει ήδη. Αντικατάσταση;", "Επιβεβαίωση", 0x34)
        if result = "No"
            return
        FileDelete(SaveFile)
    }
    
    ; Αποθήκευση όλων των στοιχείων
    for apartment, data in Apartments {
        IniWrite(data.owner, SaveFile, apartment, "Owner")
        IniWrite(data.hasHeating ? "1" : "0", SaveFile, apartment, "HasHeating")
        IniWrite(Format("{:.6f}", data.ei), SaveFile, apartment, "ei")
        IniWrite(Format("{:.4f}", data.fi), SaveFile, apartment, "fi")
        IniWrite(Format("{:.2f}", data.hours), SaveFile, apartment, "Hours")
        IniWrite(Format("{:.4f}", data.pi), SaveFile, apartment, "Pi")
    }
    
    ; Ενημέρωση GUI
    HeatFileText.Text := SaveFile
    
    MsgBox("Τα δεδομένα αποθηκεύτηκαν επιτυχώς στο:`n" SaveFile, "Επιτυχία", 0x40)
}

TransferHeatingPercent(*) {
    global Apartments, OriginalINIFile
    
    if Apartments.Count = 0 {
        MsgBox("Δεν υπάρχουν διαμερίσματα!", "Πληροφορία", 0x40)
        return
    }
    
    if OriginalINIFile = "" {
        MsgBox("Δεν έχει επιλεγεί αρχικό αρχείο!", "Σφάλμα", 0x10)
        return
    }
    
    ; Ελέγχουμε αν υπάρχουν υπολογισμένα Pi
    hasCalculatedPi := false
    for apartment, data in Apartments {
        if data.HasOwnProp("pi") && data.pi > 0 {
            hasCalculatedPi := true
            break
        }
    }
    
    if !hasCalculatedPi {
        MsgBox("Δεν έχουν υπολογιστεί τα Πi!`nΠατήστε 'Υπολογισμός' πρώτα.", "Προειδοποίηση", 0x30)
        return
    }
    
    result := MsgBox(
        "Θα δημιουργηθεί νέο αρχείο με τα HeatingPercent αντικατεστημένα από τα Πi:`n`n"
        . "Αρχείο Προέλευσης: " OriginalINIFile "`n`n"
        . "⚠️ ΤΟ ΑΡΧΙΚΟ ΑΡΧΕΙΟ ΔΕ ΘΑ ΑΛΛΑΞΕΙ!`n"
        . "⚠️ Τα Pi (%) θα πολλαπλασιαστούν x10 για να γίνουν 'της χιλιοστής'`n`n"
        . "Παράδειγμα: Pi = 5.1500% → HeatingPercent = 51.50`n`n"
        . "Συνέχεια;",
        "Μεταφορά Ποσοστού Θέρμανσης",
        0x34
    )
    
    if result = "No"
        return
    
    ; Διάβασμα ολόκληρου του αρχικού αρχείου
    if !FileExist(OriginalINIFile) {
        MsgBox("Το αρχικό αρχείο δεν βρέθηκε!", "Σφάλμα", 0x10)
        return
    }
    
    ; Προτεινόμενο όνομα για το νέο αρχείο
    SplitPath(OriginalINIFile, &name, &dir, &ext)
    nameWithoutExt := SubStr(name, 1, -4)
    suggestedName := dir "\" nameWithoutExt "_UPDATED.ini"
    
    ; Διάλογος αποθήκευσης αρχείου
    SaveFile := FileSelect("S16", suggestedName, "Αποθήκευση Αρχείου με Μεταφορά Θέρμανσης", "INI Files (*.ini)")
    
    if SaveFile = ""
        return
    
    ; Προσθήκη .ini αν δεν υπάρχει
    if !InStr(SaveFile, ".ini")
        SaveFile .= ".ini"
    
    ; Έλεγχος αν υπάρχει ήδη
    if FileExist(SaveFile) {
        result2 := MsgBox("Το αρχείο υπάρχει ήδη. Αντικατάσταση;", "Επιβεβαίωση", 0x34)
        if result2 = "No"
            return
    }
    
    try {
        originalContent := FileRead(OriginalINIFile)
        
        ; Αντικατάσταση κάθε HeatingPercent με το αντίστοιχο Pi × 10
        for apartment, data in Apartments {
            if data.HasOwnProp("pi") {
                ; ΣΗΜΑΝΤΙΚΟ: Πολλαπλασιάζουμε το Pi επί 10
                ; π.χ. Pi = 5.1500% → HeatingPercent = 51.50
                heatingValue := data.pi * 10
                
                ; Βρίσκουμε το pattern [ΔΙΑΜΕΡΙΣΜΑ]...HeatingPercent=XX
                ; και το αντικαθιστούμε με το Pi × 10
                pattern := "(\[" apartment "\][\s\S]*?HeatingPercent=)[\d\.]+"
                replacement := "$1" Format("{:.2f}", heatingValue)
                originalContent := RegExReplace(originalContent, pattern, replacement)
            }
        }
        
        ; Αποθήκευση νέου αρχείου
        if FileExist(SaveFile)
            FileDelete(SaveFile)
        FileAppend(originalContent, SaveFile)
        
        MsgBox(
            "Επιτυχής μεταφορά!`n`n"
            . "Νέο αρχείο: " SaveFile "`n`n"
            . "Τα HeatingPercent αντικαταστάθηκαν με τα Πi × 10`n"
            . "(Μετατροπή από % σε 'της χιλιοστής')",
            "Επιτυχία",
            0x40
        )
        
    } catch as e {
        MsgBox("Σφάλμα κατά τη μεταφορά: " e.Message, "Σφάλμα", 0x10)
    }
}

GuiClose(*) {
    ExitApp
}

MyGui.OnEvent("Close", GuiClose)
MyGui.OnEvent("Escape", GuiClose)