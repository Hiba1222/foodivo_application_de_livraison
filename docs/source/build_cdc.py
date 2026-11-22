# -*- coding: utf-8 -*-
"""Génère le cahier des charges Foodivo (PDF) avec ReportLab."""
import sys
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_JUSTIFY
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (BaseDocTemplate, Frame, PageTemplate, Paragraph, Spacer, Table,
                                TableStyle, PageBreak, KeepTogether, Image, NextPageTemplate, CondPageBreak)
from reportlab.platypus.tableofcontents import TableOfContents
from reportlab.graphics.shapes import Drawing, Rect, String, Line, Polygon

OUT, LOGO = sys.argv[1], sys.argv[2]

# ---------- Fonts ----------
F = "C:/Windows/Fonts/"
pdfmetrics.registerFont(TTFont("UI", F + "segoeui.ttf"))
pdfmetrics.registerFont(TTFont("UI-B", F + "segoeuib.ttf"))
pdfmetrics.registerFont(TTFont("UI-L", F + "segoeuil.ttf"))
pdfmetrics.registerFont(TTFont("UI-I", F + "segoeuii.ttf") if __import__("os").path.exists(F + "segoeuii.ttf") else TTFont("UI-I", F + "segoeui.ttf"))
from reportlab.pdfbase.pdfmetrics import registerFontFamily
registerFontFamily("UI", normal="UI", bold="UI-B", italic="UI-I", boldItalic="UI-B")

# ---------- Palette (charte Foodivo) ----------
BRAND = colors.HexColor("#EA580C")
BRAND5 = colors.HexColor("#F97316")
BRAND50 = colors.HexColor("#FFF7ED")
BRAND100 = colors.HexColor("#FFEDD5")
ROSE = colors.HexColor("#F43F5E")
ROSE600 = colors.HexColor("#E11D48")
AMBER = colors.HexColor("#F59E0B")
GREEN = colors.HexColor("#16A34A")
BLUE = colors.HexColor("#1D4ED8")
S900 = colors.HexColor("#0F172A")
S700 = colors.HexColor("#334155")
S500 = colors.HexColor("#64748B")
S400 = colors.HexColor("#94A3B8")
S200 = colors.HexColor("#E2E8F0")
S100 = colors.HexColor("#F1F5F9")
S50 = colors.HexColor("#F8FAFC")
WHITE = colors.white

# ---------- Styles ----------
def st(name, **kw):
    base = dict(fontName="UI", fontSize=10, leading=14.5, textColor=S700)
    base.update(kw)
    return ParagraphStyle(name, **base)

BODY = st("body", alignment=TA_JUSTIFY, spaceAfter=6)
BODY_L = st("bodyl", spaceAfter=4)
SMALL = st("small", fontSize=8.5, leading=11.5, textColor=S500)
CELL = st("cell", fontSize=8.8, leading=12)
CELL_B = st("cellb", fontName="UI-B", fontSize=8.8, leading=12, textColor=S900)
CELL_H = st("cellh", fontName="UI-B", fontSize=8.8, leading=12, textColor=WHITE)
H1 = st("h1", fontName="UI-B", fontSize=20, leading=25, textColor=S900, spaceBefore=4, spaceAfter=10)
H2 = st("h2", fontName="UI-B", fontSize=13.5, leading=18, textColor=BRAND, spaceBefore=12, spaceAfter=6)
H3 = st("h3", fontName="UI-B", fontSize=11, leading=15, textColor=S900, spaceBefore=8, spaceAfter=4)
BULLET = st("bullet", leftIndent=14, bulletIndent=3, spaceAfter=2.5)
TOC1 = st("toc1", fontName="UI-B", fontSize=10.5, leading=17, textColor=S900, leftIndent=0)
TOC2 = st("toc2", fontSize=9.5, leading=14, textColor=S500, leftIndent=16)

# ---------- Doc with TOC notifications ----------
class Doc(BaseDocTemplate):
    def afterFlowable(self, f):
        if isinstance(f, Paragraph) and getattr(f, "_toc", None):
            level, text = f._toc
            key = "h%s" % id(f)
            self.canv.bookmarkPage(key)
            self.canv.addOutlineEntry(text, key, level=level, closed=False)
            self.notify("TOCEntry", (level, text, self.page, key))

_sec = [0, 0]
def h1(text):
    _sec[0] += 1; _sec[1] = 0
    t = "%d. %s" % (_sec[0], text)
    p = Paragraph(t, H1); p._toc = (0, t)
    bar = Table([[""]], colWidths=[28 * mm], rowHeights=[3])
    bar.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), BRAND), ("LEFTPADDING", (0, 0), (-1, -1), 0)]))
    bar.hAlign = "LEFT"
    return [CondPageBreak(60 * mm), Spacer(1, 14), p, bar, Spacer(1, 8)]

def h2(text):
    _sec[1] += 1
    t = "%d.%d %s" % (_sec[0], _sec[1], text)
    p = Paragraph(t, H2); p._toc = (1, t)
    return p

def h3(text): return Paragraph(text, H3)
def P(text, style=BODY): return Paragraph(text, style)
def bullets(items, style=BULLET):
    return [Paragraph(i, style, bulletText="\u2022") for i in items]

W = A4[0] - 2 * 20 * mm  # usable width

def table(rows, widths, header=True, zebra=True, head_bg=S900, font=CELL):
    data = []
    for r_i, row in enumerate(rows):
        cells = []
        for c in row:
            if isinstance(c, str):
                cells.append(Paragraph(c, CELL_H if (header and r_i == 0) else font))
            else:
                cells.append(c)
        data.append(cells)
    t = Table(data, colWidths=[w * W for w in widths], repeatRows=1 if header else 0)
    style = [
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6), ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 4.5), ("BOTTOMPADDING", (0, 0), (-1, -1), 4.5),
        ("LINEBELOW", (0, 0), (-1, -1), 0.4, S200),
    ]
    if header:
        style += [("BACKGROUND", (0, 0), (-1, 0), head_bg)]
    if zebra:
        for i in range(1 if header else 0, len(data)):
            if i % 2 == 0:
                style.append(("BACKGROUND", (0, i), (-1, i), S50))
    t.setStyle(TableStyle(style))
    return t

PRIO = {"Must": ("Essentielle", ROSE600), "Should": ("Importante", AMBER), "Could": ("Souhaitable", BLUE)}
def prio(p):
    label, col = PRIO[p]
    return Paragraph('<font color="%s"><b>%s</b></font>' % (col.hexval().replace("0x", "#"), label), CELL)

def status(done):
    return Paragraph('<font color="%s"><b>%s</b></font>' % (("#16A34A", "Réalisé") if done is True else (("#F59E0B", "En cours") if done == "wip" else ("#64748B", "Prévu"))), CELL)

def req(rows):
    """rows: (id, texte, prio, done)"""
    data = [["ID", "Exigence", "Priorité", "État"]]
    for rid, txt, p, d in rows:
        data.append([Paragraph("<b>%s</b>" % rid, CELL_B), Paragraph(txt, CELL), prio(p), status(d)])
    return table(data, [0.11, 0.6, 0.15, 0.14])

def note(text, title="À noter", color=BRAND, bg=BRAND50):
    t = Table([[Paragraph('<font color="%s"><b>%s</b></font><br/>%s' % (color.hexval().replace("0x", "#"), title, text), CELL)]], colWidths=[W])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), bg), ("LINEBEFORE", (0, 0), (0, -1), 3, color),
        ("LEFTPADDING", (0, 0), (-1, -1), 10), ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING", (0, 0), (-1, -1), 7), ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
    ]))
    return KeepTogether([Spacer(1, 4), t, Spacer(1, 8)])

def field_table(rows):
    """Champs à compléter (modèle)."""
    data = [[Paragraph("<b>%s</b>" % a, CELL_B), Paragraph(b, CELL)] for a, b in rows]
    t = Table(data, colWidths=[0.32 * W, 0.68 * W])
    t.setStyle(TableStyle([
        ("GRID", (0, 0), (-1, -1), 0.5, S200), ("BACKGROUND", (0, 0), (0, -1), S50),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 6), ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
        ("LEFTPADDING", (0, 0), (-1, -1), 7),
    ]))
    return t

# ---------- Diagrams ----------
def box(d, x, y, w, h, title, sub, fill, fg=WHITE, subfg=None):
    d.add(Rect(x, y, w, h, rx=7, ry=7, fillColor=fill, strokeColor=None))
    d.add(String(x + w / 2, y + h - 17, title, fontName="UI-B", fontSize=9.5, fillColor=fg, textAnchor="middle"))
    for i, line in enumerate(sub):
        d.add(String(x + w / 2, y + h - 31 - i * 11, line, fontName="UI", fontSize=7.6, fillColor=subfg or fg, textAnchor="middle"))

def arrow(d, x1, y1, x2, y2, label=None, color=S400):
    d.add(Line(x1, y1, x2, y2, strokeColor=color, strokeWidth=1.3))
    import math
    a = math.atan2(y2 - y1, x2 - x1); s = 5
    d.add(Polygon([x2, y2, x2 - s * math.cos(a - 0.45), y2 - s * math.sin(a - 0.45), x2 - s * math.cos(a + 0.45), y2 - s * math.sin(a + 0.45)], fillColor=color, strokeColor=None))
    if label:
        d.add(String((x1 + x2) / 2, (y1 + y2) / 2 + 4, label, fontName="UI", fontSize=7, fillColor=S500, textAnchor="middle"))

def architecture():
    w, h = W, 262
    d = Drawing(w, h)
    # left column: interfaces
    box(d, 0, 186, 140, 62, "Site web (Next.js 14)", ["Clients · Restaurants", "Livreurs · Admin"], BRAND)
    box(d, 0, 104, 140, 62, "App Android (Flutter)", ["Clients (phase 1)", "Livreurs, restos : phases 2-3"], ROSE)
    box(d, 0, 22, 140, 62, "Appareil de l'utilisateur", ["Navigateur · Téléphone", "GPS · Appels"], S700)
    # middle: Next.js server
    box(d, 160, 170, 118, 84, "Serveur Next.js", ["Server Components", "Server Actions", "Middleware des rôles", "i18n FR / EN"], S900)
    # right: Supabase panel with stacked services
    px, pw = 300, w - 300
    d.add(Rect(px, 0, pw, h, rx=9, ry=9, fillColor=BRAND50, strokeColor=BRAND100))
    d.add(String(px + pw / 2, h - 17, "Supabase (BaaS)", fontName="UI-B", fontSize=10.5, fillColor=BRAND, textAnchor="middle"))
    rows = [("PostgreSQL + RLS", "Tables · politiques d'accès · PostGIS"),
            ("Auth", "E-mail / mot de passe · sessions JWT"),
            ("Realtime", "Tables orders et driver_profiles"),
            ("Storage", "Bucket « media » : logos et photos"),
            ("Fonctions SQL (RPC)", "place_order · get_order_driver · auth_role")]
    bh, gap, top = 38, 7, h - 30
    for i, (t, sub) in enumerate(rows):
        y = top - (i + 1) * bh - i * gap
        d.add(Rect(px + 10, y, pw - 20, bh, rx=6, ry=6, fillColor=WHITE, strokeColor=BRAND100))
        d.add(String(px + 20, y + bh - 15, t, fontName="UI-B", fontSize=8.8, fillColor=S900))
        d.add(String(px + 20, y + 9, sub, fontName="UI", fontSize=7.4, fillColor=S500))
    # arrows
    arrow(d, 140, 217, 160, 212, None)
    d.add(String(150, 232, "HTTPS", fontName="UI", fontSize=7, fillColor=S500, textAnchor="middle"))
    arrow(d, 278, 212, 310, 212, None)
    d.add(String(294, 220, "SDK", fontName="UI", fontSize=7, fillColor=S500, textAnchor="middle"))
    arrow(d, 140, 135, 310, 135, None, ROSE)
    d.add(String(225, 141, "SDK Supabase (direct)", fontName="UI", fontSize=7, fillColor=ROSE, textAnchor="middle"))
    return d

def lifecycle():
    steps = [("pending", "En attente", S500), ("accepted", "Acceptée", BLUE), ("ready_for_pickup", "Prête", colors.HexColor("#4338CA")),
             ("driver_assigned", "Livreur assigné", colors.HexColor("#4338CA")), ("picked_up", "Récupérée", colors.HexColor("#7E22CE")), ("delivered", "Livrée", GREEN)]
    w, h = W, 120
    d = Drawing(w, h)
    bw, gap = 74, (W - 6 * 74) / 5
    who = ["Client", "Restaurant", "Restaurant", "Livreur", "Livreur", "Livreur"]
    for i, (code, label, col) in enumerate(steps):
        x = i * (bw + gap)
        d.add(Rect(x, 52, bw, 44, rx=8, ry=8, fillColor=col, strokeColor=None))
        d.add(String(x + bw / 2, 77, label, fontName="UI-B", fontSize=8.2, fillColor=WHITE, textAnchor="middle"))
        d.add(String(x + bw / 2, 63, code, fontName="UI", fontSize=6.6, fillColor=WHITE, textAnchor="middle"))
        d.add(String(x + bw / 2, 103, "par : " + who[i], fontName="UI", fontSize=7, fillColor=S500, textAnchor="middle"))
        if i < 5:
            arrow(d, x + bw + 2, 74, x + bw + gap - 2, 74)
    # branches
    d.add(Rect(bw + gap - 10, 6, bw + 20, 30, rx=7, ry=7, fillColor=colors.HexColor("#FEE2E2"), strokeColor=None))
    d.add(String(bw + gap + bw / 2, 17, "Refusée (rejected)", fontName="UI-B", fontSize=7.8, fillColor=colors.HexColor("#B91C1C"), textAnchor="middle"))
    arrow(d, bw / 2, 52, bw + gap - 10, 24, None, colors.HexColor("#F87171"))
    d.add(Rect(3 * (bw + gap) - 10, 6, bw + 20, 30, rx=7, ry=7, fillColor=S100, strokeColor=None))
    d.add(String(3 * (bw + gap) + bw / 2, 17, "Annulée (cancelled)", fontName="UI-B", fontSize=7.8, fillColor=S500, textAnchor="middle"))
    return d

def swatches():
    items = [("#EA580C", "Orange Foodivo", "brand-600"), ("#F97316", "Orange vif", "brand-500"), ("#FFF7ED", "Crème", "brand-50"),
             ("#F43F5E", "Rose", "rose-500"), ("#E11D48", "Rose promo", "rose-600"), ("#F59E0B", "Ambre", "amber-500"),
             ("#0F172A", "Ardoise", "slate-900"), ("#16A34A", "Vert", "green-600")]
    w = W; d = Drawing(w, 92)
    bw = (w - 7 * 8) / 8
    for i, (hx, name, token) in enumerate(items):
        x = i * (bw + 8)
        d.add(Rect(x, 38, bw, 48, rx=7, ry=7, fillColor=colors.HexColor(hx), strokeColor=S200 if hx == "#FFF7ED" else None))
        d.add(String(x + bw / 2, 26, name, fontName="UI-B", fontSize=7.4, fillColor=S900, textAnchor="middle"))
        d.add(String(x + bw / 2, 15, hx, fontName="UI", fontSize=7, fillColor=S500, textAnchor="middle"))
        d.add(String(x + bw / 2, 4, token, fontName="UI", fontSize=6.6, fillColor=S400, textAnchor="middle"))
    return d

# ---------- Page decorations ----------
DATE = "16 novembre 2026"
VERSION = "1.0"

def cover(c, doc):
    w, h = A4
    c.saveState()
    c.setFillColor(WHITE); c.rect(0, 0, w, h, stroke=0, fill=1)
    # gradient band
    steps = 60
    for i in range(steps):
        t = i / (steps - 1)
        r = 0xF9 + (0xF4 - 0xF9) * t; g = 0x73 + (0x3F - 0x73) * t; b = 0x16 + (0x5E - 0x16) * t
        c.setFillColorRGB(r / 255, g / 255, b / 255)
        c.rect(w * i / steps, 0, w / steps + 1, 92 * mm, stroke=0, fill=1)
    c.setFillColor(colors.Color(1, 1, 1, alpha=0.12)); c.circle(w - 30 * mm, 70 * mm, 45 * mm, stroke=0, fill=1)
    c.setFillColor(colors.Color(1, 1, 1, alpha=0.10)); c.circle(25 * mm, 20 * mm, 30 * mm, stroke=0, fill=1)
    c.setFillAlpha(1); c.setStrokeAlpha(1)
    # logo
    c.drawImage(LOGO, (w - 120 * mm) / 2, h - 105 * mm, width=120 * mm, height=120 * mm * 231 / 471, mask="auto")
    c.setFillColor(BRAND); c.rect((w - 30 * mm) / 2, h - 118 * mm, 30 * mm, 1.2 * mm, stroke=0, fill=1)
    c.setFillColor(S900); c.setFont("UI-B", 34); c.drawCentredString(w / 2, h - 140 * mm, "Cahier des charges")
    c.setFillColor(S500); c.setFont("UI", 14)
    c.drawCentredString(w / 2, h - 151 * mm, "Plateforme de livraison de repas Foodivo")
    c.drawCentredString(w / 2, h - 159 * mm, "Site web · Application Android · Back-office Supabase")
    # meta card
    y0 = h - 200 * mm
    c.setFillColor(S50); c.setStrokeColor(S200); c.roundRect(25 * mm, y0, w - 50 * mm, 30 * mm, 4 * mm, stroke=1, fill=1)
    c.setFont("UI-B", 9.5); c.setFillColor(S900)
    labels = [("Version", VERSION), ("Date", DATE), ("Statut", "Référence"), ("Langue", "Français")]
    for i, (k, v) in enumerate(labels):
        x = 25 * mm + (w - 50 * mm) / 4 * (i + 0.5)
        c.setFillColor(S400); c.setFont("UI", 8.5); c.drawCentredString(x, y0 + 19 * mm, k.upper())
        c.setFillColor(S900); c.setFont("UI-B", 10.5); c.drawCentredString(x, y0 + 11 * mm, v)
    c.setFillColor(WHITE); c.setFont("UI-B", 12)
    c.drawString(20 * mm, 40 * mm, "Commande · Personnalisation · Promotions · Suivi en temps réel")
    c.setFont("UI", 10); c.drawString(20 * mm, 32 * mm, "Clients · Restaurants · Livreurs · Administration — bilingue français / anglais — prix en dinars (TND)")
    c.setFont("UI", 8.5); c.drawString(20 * mm, 14 * mm, "Document confidentiel — usage interne au projet Foodivo")
    c.restoreState()

def page(c, doc):
    w, h = A4
    c.saveState()
    c.drawImage(LOGO, 20 * mm, h - 15 * mm, width=22 * mm, height=22 * mm * 231 / 471, mask="auto")
    c.setFont("UI", 8); c.setFillColor(S400)
    c.drawRightString(w - 20 * mm, h - 11.5 * mm, "Cahier des charges — Foodivo · v%s" % VERSION)
    c.setStrokeColor(S200); c.setLineWidth(0.6); c.line(20 * mm, h - 17 * mm, w - 20 * mm, h - 17 * mm)
    c.setFillColor(BRAND); c.rect(20 * mm, h - 17.3 * mm, 18 * mm, 0.9 * mm, stroke=0, fill=1)
    c.line(20 * mm, 14 * mm, w - 20 * mm, 14 * mm)
    c.setFillColor(S400); c.drawString(20 * mm, 9 * mm, DATE)
    c.setFillColor(S900); c.setFont("UI-B", 8.5); c.drawRightString(w - 20 * mm, 9 * mm, "Page %d" % doc.page)
    c.restoreState()

doc = Doc(OUT, pagesize=A4, leftMargin=20 * mm, rightMargin=20 * mm, topMargin=24 * mm, bottomMargin=20 * mm,
          title="Cahier des charges — Foodivo", author="Équipe projet Foodivo", subject="Plateforme de livraison de repas",
          creator="Foodivo")
frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id="f")
doc.addPageTemplates([PageTemplate(id="cover", frames=[frame], onPage=cover), PageTemplate(id="body", frames=[frame], onPage=page)])

S = []
S += [NextPageTemplate("body"), PageBreak()]

# ---------- Fiche document ----------
S.append(Paragraph("Fiche du document", H1))
S.append(field_table([
    ("Projet", "Foodivo — plateforme de livraison de repas"),
    ("Porteur du projet / Maître d'ouvrage", "[À compléter]"),
    ("Maître d'œuvre / Équipe technique", "[À compléter]"),
    ("Établissement / Encadrant (si projet académique)", "[À compléter]"),
    ("Version du document", VERSION + " — " + DATE),
    ("Diffusion", "Équipe projet, encadrement, partenaires"),
]))
S.append(Spacer(1, 12))
S.append(Paragraph("Historique des versions", H3))
S.append(table([["Version", "Date", "Auteur", "Modifications"],
                ["0.1", "15/11/2026", "[À compléter]", "Site web : rôles, menus, commandes, suivi"],
                ["0.5", "15/11/2026", "[À compléter]", "Personnalisation des plats, devise TND, design animé, bilingue FR/EN, promotions, rebranding Foodivo"],
                ["1.0", "16/11/2026", "[À compléter]", "Application Android (phase 1 client), fonction place_order, rédaction du cahier des charges"]],
               [0.12, 0.15, 0.2, 0.53]))
S.append(Spacer(1, 12))
S.append(Paragraph("Sommaire", H1))
toc = TableOfContents(); toc.levelStyles = [TOC1, TOC2]; toc.dotsMinLevel = 0
S += [toc, PageBreak()]

# ======================= 1. Présentation =======================
S += h1("Présentation du projet")
S.append(h2("Contexte"))
S.append(P("Foodivo est une plateforme de commande et de livraison de repas destinée au marché tunisien. Elle met en relation "
           "trois populations — les <b>clients</b> qui commandent, les <b>restaurants</b> qui préparent et les <b>livreurs</b> qui "
           "acheminent — sous la supervision d'un <b>administrateur</b>. Le projet comprend un site web complet, une application "
           "Android native et une base de données hébergée sur Supabase partagée par les deux interfaces."))
S.append(P("Les restaurants partenaires de démarrage sont <b>Tozeur FastFood</b> (restauration rapide tunisienne : chapati, mlawi, "
           "casse-croûte, pizzas, ojja…) et <b>Amigo</b> (street-food : tacos, smash burgers, wings, crêpes, milkshakes). Les prix sont "
           "exprimés en <b>dinars tunisiens (TND)</b>, stockés en millimes (1 TND = 1 000 millimes)."))
S.append(h2("Objectifs"))
S += bullets([
    "Permettre à un client de trouver un restaurant, composer son repas (pain, ingrédients, suppléments), commander et suivre sa livraison <b>en temps réel</b>.",
    "Donner aux restaurants un back-office simple : menu, photos, options de personnalisation, <b>promotions</b> et gestion des commandes.",
    "Offrir aux livreurs un espace pour accepter des courses, partager leur position et suivre leurs gains.",
    "Garantir à l'administrateur le contrôle de la plateforme : validation des restaurants et livreurs, vue sur toutes les commandes.",
    "Proposer une expérience moderne, animée et <b>bilingue français / anglais</b>, identique sur le web et sur mobile.",
    "Assurer la sécurité des données et l'intégrité des prix (calculés côté serveur, jamais par le client).",
])
S.append(h2("Périmètre"))
S.append(table([["Dans le périmètre", "Hors périmètre (version actuelle)"],
                ["Site web responsive pour les 4 rôles<br/>Application Android pour les clients (phase 1)<br/>Personnalisation des plats et promotions<br/>Suivi de commande en temps réel<br/>Contact du livreur (nom, téléphone, appel)<br/>Interface bilingue FR / EN",
                 "Paiement en ligne (carte, D17, Flouci…)<br/>Notifications push<br/>Géocodage automatique des adresses<br/>Application iOS<br/>Avis et notes (table prévue, non exploitée)<br/>Facturation et comptabilité restaurant"]],
               [0.5, 0.5], zebra=False))
S.append(h2("Glossaire"))
S.append(table([["Terme", "Définition"],
                ["Millime", "Unité de stockage des prix : 1 TND = 1 000 millimes. Ex. 9 500 = 9,500 TND."],
                ["Groupe d'options", "Ensemble de choix pour un plat : « Choix » (pain, taille, sauces) ou « Ingrédients » (Sans / Normal / Extra)."],
                ["Offre / Promotion", "Prix réduit sur un plat, avec étiquette et date de fin facultatives ; ou plat « mis en avant »."],
                ["RLS", "Row Level Security : règles PostgreSQL qui limitent chaque utilisateur à ses propres données."],
                ["RPC", "Fonction SQL appelée par l'application (ex. place_order)."],
                ["Temps réel", "Mise à jour automatique des écrans quand une donnée change (Supabase Realtime)."]],
               [0.22, 0.78]))

# ======================= 2. Acteurs =======================
S += h1("Acteurs et rôles")
S.append(P("Chaque compte possède un rôle unique, défini à l'inscription et stocké dans la table <i>profiles</i>. Un middleware "
           "redirige automatiquement chaque utilisateur vers son espace et bloque l'accès aux espaces des autres rôles."))
S.append(table([["Rôle", "Description", "Espace", "Validation"],
                ["<b>Client</b>", "Parcourt les restaurants, personnalise et commande des plats, suit sa livraison, contacte le livreur.", "/client · App Android", "Immédiate"],
                ["<b>Restaurateur</b>", "Crée son restaurant, gère menu, options, photos, promotions et commandes.", "/restaurant", "Par l'administrateur"],
                ["<b>Livreur</b>", "Se met en ligne, accepte des livraisons, partage sa position GPS, marque récupérée / livrée.", "/driver", "Par l'administrateur"],
                ["<b>Administrateur</b>", "Supervise la plateforme : approbations, commandes, utilisateurs, statistiques.", "/admin", "Compte interne"]],
               [0.19, 0.47, 0.17, 0.17]))

# ======================= 3. Fonctionnel =======================
S += h1("Besoins fonctionnels")
S.append(P("Les exigences sont identifiées (RF-xx), priorisées selon la méthode MoSCoW (<b>Essentielle</b>, <b>Importante</b>, "
           "<b>Souhaitable</b>) et accompagnées de leur état de réalisation au %s." % DATE))
S.append(h2("Comptes et authentification"))
S.append(req([
    ("RF-01", "Inscription par e-mail et mot de passe (6 caractères min.) avec choix du rôle : client, restaurant ou livreur ; nom complet et téléphone obligatoires.", "Must", True),
    ("RF-02", "Connexion avec redirection automatique vers l'espace correspondant au rôle.", "Must", True),
    ("RF-03", "Protection des routes : un utilisateur non connecté est renvoyé vers la connexion ; un rôle ne peut pas accéder à l'espace d'un autre (page « Accès refusé »).", "Must", True),
    ("RF-04", "Complétion du profil client au premier accès : téléphone et première adresse de livraison obligatoires avant de commander.", "Must", True),
    ("RF-05", "Déconnexion depuis la barre latérale (web) ou les paramètres (mobile).", "Must", True),
]))
S.append(h2("Espace client"))
S.append(req([
    ("RF-10", "Page d'accueil avec bannière animée, carrousel « Bons plans » des offres de tous les restaurants et liste des restaurants approuvés.", "Must", True),
    ("RF-11", "Recherche instantanée (nom, cuisine, description) et filtres : cuisine, « Ouvert », « Promos ».", "Should", True),
    ("RF-12", "Carte restaurant : photo de couverture, logo, statut ouvert / fermé (point animé), temps de préparation, badge « Jusqu'à -X % ».", "Must", True),
    ("RF-13", "Page restaurant : couverture plein écran, section « Offres spéciales », onglets de catégories collants, plats regroupés par catégorie.", "Must", True),
    ("RF-14", "Fenêtre de personnalisation d'un plat : choix obligatoires / facultatifs, ingrédients Sans / Normal / Extra, instructions spéciales, quantité, prix mis à jour en direct.", "Must", True),
    ("RF-15", "Contrôle des choix obligatoires : impossible d'ajouter au panier tant qu'un groupe requis n'est pas rempli (section mise en évidence et secouée).", "Must", True),
    ("RF-16", "Panier mono-restaurant : ajout d'un plat d'un autre restaurant après confirmation de vidage ; fusion des lignes identiques ; modification des quantités.", "Must", True),
    ("RF-17", "Validation de commande : choix ou ajout d'adresse, note pour le restaurant, récapitulatif (sous-total, frais de livraison 2,500 TND, total).", "Must", True),
    ("RF-18", "Historique « Mes commandes » mis à jour en temps réel avec statut coloré.", "Must", True),
    ("RF-19", "Suivi de commande : frise chronologique horodatée, détail des articles et options, totaux, mise à jour en direct.", "Must", True),
    ("RF-20", "Carte livreur pendant la livraison : nom, téléphone, véhicule, bouton « Appeler », position sur carte.", "Must", True),
    ("RF-21", "Paramètres : photo de profil, téléphone, gestion des adresses (ajout, suppression, adresse par défaut), langue.", "Should", True),
]))
S.append(h2("Espace restaurant"))
S.append(req([
    ("RF-30", "Création du restaurant (nom, cuisine, description, adresse, téléphone) ; bandeau d'attente tant que l'administrateur n'a pas validé.", "Must", True),
    ("RF-31", "Tableau de bord : commandes en attente, en cours, chiffre d'affaires du jour ; bouton ouvert / fermé.", "Must", True),
    ("RF-32", "Gestion du menu : catégories, plats (nom, prix TND, description, catégorie), disponibilité instantanée, suppression.", "Must", True),
    ("RF-33", "Photos : logo, couverture et photo de chaque plat (stockage Supabase « media »).", "Should", True),
    ("RF-34", "Personnalisation des plats : groupes « Choix » (min / max) et « Ingrédients », options avec prix, présélection, « peut être en extra », rupture de stock, réordonnancement.", "Must", True),
    ("RF-35", "Modèles prêts à l'emploi (pain, ingrédients, suppléments, sauces, taille, menu, boisson) insérés dans la langue du restaurateur ; copie des options d'un autre plat.", "Should", True),
    ("RF-36", "Aperçu client de la fenêtre de personnalisation.", "Could", True),
    ("RF-37", "Promotions : prix promo (raccourcis -10 % à -50 %), étiquette, date de fin, mise en avant « Offres spéciales » ; retrait de l'offre.", "Must", True),
    ("RF-38", "Commandes reçues en temps réel : accepter, refuser, marquer « prête à récupérer » ; affichage des options (retraits en rouge pour la cuisine).", "Must", True),
]))
S.append(h2("Espace livreur"))
S.append(req([
    ("RF-50", "Création du profil livreur (véhicule : vélo, scooter, voiture ; plaque ; téléphone) puis validation par l'administrateur.", "Must", True),
    ("RF-51", "Passage en ligne / hors ligne ; seuls les livreurs approuvés et en ligne voient les courses.", "Must", True),
    ("RF-52", "Liste des livraisons disponibles en temps réel (retrait, dépôt, frais) ; le premier qui accepte obtient la course.", "Must", True),
    ("RF-53", "Mes livraisons : coordonnées du client, boutons « J'ai récupéré la commande » puis « Marquer comme livrée ».", "Must", True),
    ("RF-54", "Partage de la position GPS pendant que le livreur est en ligne.", "Must", True),
    ("RF-55", "Historique des livraisons et gains du jour.", "Should", True),
]))
S.append(h2("Espace administrateur"))
S.append(req([
    ("RF-70", "Vue d'ensemble en temps réel : commandes totales et actives, restaurants et livreurs en attente, chiffre d'affaires des commandes payées.", "Must", True),
    ("RF-71", "Approbation / suspension des restaurants et des livreurs.", "Must", True),
    ("RF-72", "Liste de toutes les commandes (restaurant, client, total, statut, date).", "Must", True),
    ("RF-73", "Liste des utilisateurs (nom, téléphone, rôle, date d'inscription).", "Should", True),
]))
S.append(h2("Fonctions transverses"))
S.append(req([
    ("RF-90", "Interface bilingue français / anglais avec sélecteur animé ; choix mémorisé ; langue du navigateur ou du téléphone au premier lancement ; dates localisées.", "Must", True),
    ("RF-91", "Mises à jour en temps réel (commandes, position livreur) sans rechargement.", "Must", True),
    ("RF-92", "Design animé : apparitions en cascade, cartes qui se soulèvent, boutons qui réagissent au toucher ; respect du réglage « réduire les animations ».", "Should", True),
    ("RF-93", "Interface responsive : barre latérale sur ordinateur, barre d'onglets en bas sur mobile.", "Must", True),
    ("RF-94", "Notifications push (nouvelle commande, commande en route, nouvelle course).", "Should", False),
    ("RF-95", "Paiement en ligne.", "Could", False),
]))

# ======================= 4. Cycle de vie =======================
S += h1("Cycle de vie d'une commande")
S.append(P("Chaque changement de statut est horodaté dans <i>order_status_history</i> et diffusé en temps réel au client, au "
           "restaurant et au livreur concernés."))
S.append(lifecycle())
S.append(Spacer(1, 6))
S.append(table([["Statut", "Déclencheur", "Effet visible"],
                ["pending — En attente", "Le client valide sa commande", "La commande apparaît chez le restaurant"],
                ["accepted — Acceptée", "Le restaurant accepte", "Le client voit « Acceptée par le restaurant »"],
                ["rejected — Refusée", "Le restaurant refuse", "Fin de la commande, message au client"],
                ["ready_for_pickup — Prête", "Le restaurant marque la commande prête", "Elle apparaît dans « Livraisons disponibles »"],
                ["driver_assigned — Livreur assigné", "Un livreur accepte la course", "Carte livreur (nom, téléphone, appel) chez le client"],
                ["picked_up — Récupérée", "Le livreur confirme le retrait", "« Votre commande est en route »"],
                ["delivered — Livrée", "Le livreur confirme la livraison", "Fin du suivi, gains du livreur mis à jour"],
                ["cancelled — Annulée", "Échec technique lors de la création", "Commande incomplète neutralisée"]],
               [0.3, 0.34, 0.36]))

# ======================= 5. Règles de gestion =======================
S += h1("Règles de gestion")
S.append(table([["Réf.", "Règle"],
                ["RG-01", "Tous les montants sont des entiers en millimes (TND). Affichage : « 7.500 TND »."],
                ["RG-02", "Frais de livraison forfaitaires : <b>2,500 TND</b> par commande."],
                ["RG-03", "Un panier ne contient que des plats d'un seul restaurant."],
                ["RG-04", "Prix unitaire = prix de base (ou prix promo actif) + prix des options « ajout » et « extra ». Les retraits d'ingrédients sont gratuits. La remise ne s'applique jamais aux suppléments."],
                ["RG-05", "Une offre est active si son prix est strictement inférieur au prix normal et que sa date de fin n'est pas dépassée. Elle s'arrête automatiquement à échéance."],
                ["RG-06", "Le pourcentage affiché = arrondi de (1 − prix promo / prix normal) × 100."],
                ["RG-07", "Groupe « Choix » : nombre de sélections entre min et max ; min ≥ 1 rend le groupe obligatoire ; min 1 + max 1 = choix unique. Groupe « Ingrédients » : Sans / Normal / Extra (Extra si autorisé)."],
                ["RG-08", "Le prix final est <b>toujours recalculé côté serveur</b> (Server Action web ou fonction <i>place_order</i>) : le prix envoyé par l'appareil n'est jamais utilisé."],
                ["RG-09", "Un plat indisponible ou une option en rupture bloque la commande avec un message explicite."],
                ["RG-10", "Seuls les restaurants approuvés sont visibles par les clients ; seuls les livreurs approuvés peuvent se mettre en ligne."],
                ["RG-11", "Une course ne peut être acceptée que par un seul livreur (verrou sur driver_id vide)."],
                ["RG-12", "Le nom et le téléphone du livreur ne sont visibles par le client que pendant la livraison (statuts driver_assigned et picked_up)."],
                ["RG-13", "Les noms des modèles d'options sont insérés dans la langue du restaurateur ; le contenu saisi par les restaurants n'est pas traduit."]],
               [0.1, 0.9]))

# ======================= 6. Non fonctionnel =======================
S += h1("Besoins non fonctionnels")
S.append(h2("Sécurité"))
S += bullets([
    "Authentification Supabase (JWT) ; sessions rafraîchies par le middleware Next.js.",
    "<b>Row Level Security</b> sur toutes les tables métiers : chaque rôle ne lit et ne modifie que ses données.",
    "Fonctions sensibles en base (<i>place_order</i>, <i>get_order_driver</i>) avec droits d'exécution réservés aux utilisateurs connectés.",
    "Clé publique Supabase uniquement côté client ; aucune clé de service dans le code.",
    "Point connu : la table PostGIS <i>spatial_ref_sys</i> appartient à Supabase et reste accessible en écriture via l'API ; risque faible (données de référence), correction possible via le support Supabase.",
])
S.append(h2("Performance et disponibilité"))
S += bullets([
    "Affichage des pages principales en moins de 2 s sur une connexion 4G.",
    "Mises à jour temps réel visibles en moins de 2 s après le changement de statut.",
    "Images servies en taille adaptée (800 px) et mises en cache sur mobile.",
    "Hébergement managé (Supabase + hébergeur Next.js) avec sauvegardes automatiques de la base.",
])
S.append(h2("Ergonomie et accessibilité"))
S += bullets([
    "Interface responsive (ordinateur, tablette, téléphone) ; navigation mobile par onglets.",
    "Animations fluides et désactivées si l'utilisateur a activé « réduire les animations ».",
    "Libellés accessibles (aria-label) sur les boutons icônes ; contrastes conformes aux recommandations WCAG AA pour le texte.",
    "Messages d'erreur clairs et traduits.",
])
S.append(h2("Internationalisation"))
S += bullets([
    "Deux langues : français et anglais (412 textes traduits, partagés entre le web et l'application).",
    "Script de contrôle <i>scripts/check-i18n.mjs</i> signalant tout texte sans traduction.",
    "Formats de date localisés (fr-FR / en-GB) ; devise TND à trois décimales.",
])
S.append(h2("Maintenabilité"))
S += bullets([
    "Code TypeScript strict (web) et Dart analysé sans avertissement (mobile).",
    "Règles métier partagées : un seul calcul d'offre et d'options, recopié à l'identique en Dart.",
    "Migrations SQL datées et versionnées dans le dossier <i>migrations/</i>.",
    "Composants réutilisables (logo, sélecteur de langue, cartes, badges, compte à rebours).",
])

# ======================= 7. Architecture =======================
S += h1("Architecture technique")
S.append(architecture())
S.append(Spacer(1, 8))
S.append(h2("Technologies"))
S.append(table([["Couche", "Technologie", "Rôle"],
                ["Front web", "Next.js 14 (App Router), React 18, TypeScript 5", "Pages serveur, Server Actions, middleware de rôles"],
                ["Style web", "Tailwind CSS 3.4", "Charte Foodivo, animations (keyframes personnalisées)"],
                ["Mobile", "Flutter 3.50, Dart 3.14, package material_ui", "Application Android native (com.foodivo.app)"],
                ["Paquets mobiles", "supabase_flutter, provider, cached_network_image, intl, url_launcher, shared_preferences", "Données, état, images, dates, appels, préférences"],
                ["Back-end", "Supabase : PostgreSQL + PostGIS, Auth, Realtime, Storage", "Données, sécurité RLS, temps réel, fichiers"],
                ["Logique serveur", "Fonctions PL/pgSQL", "Commande sécurisée, coordonnées livreur, rôle courant"],
                ["Outils", "Node.js, Android Studio, Flutter SDK, VS Code", "Développement et compilation"]],
               [0.16, 0.42, 0.42]))
S.append(h2("Organisation du code"))
S.append(table([["Dossier", "Contenu"],
                ["web/app", "Pages par rôle : client, restaurant, driver, admin ; login, signup"],
                ["web/components", "Shell de tableau de bord, logo, sélecteur de langue, personnalisation, toasts, compte à rebours"],
                ["web/lib", "Supabase, panier, devise, options de menu, offres, i18n (fr.ts)"],
                ["mobile/lib", "core (thème, i18n, prix), data (modèles, requêtes), state (panier), ui (écrans, widgets)"],
                ["migrations", "Scripts SQL à exécuter dans l'éditeur Supabase"]],
               [0.22, 0.78]))

# ======================= 8. Données =======================
S += h1("Modèle de données")
S.append(P("Base PostgreSQL hébergée par Supabase. Toutes les tables métiers sont protégées par RLS."))
S.append(table([["Table", "Champs principaux", "Usage"],
                ["profiles", "id, role, full_name, phone, avatar_url", "Compte et rôle de chaque utilisateur"],
                ["restaurants", "owner_id, name, cuisine_type, address, phone, logo_url, cover_image_url, is_open, is_approved, avg_prep_time_minutes", "Fiche restaurant"],
                ["menu_categories", "restaurant_id, name, sort_order", "Catégories du menu"],
                ["menu_items", "restaurant_id, category_id, name, description, price_cents, image_url, is_available, offer_price_cents, offer_label, offer_ends_at, is_featured", "Plats et promotions"],
                ["menu_option_groups", "menu_item_id, name, kind (choice / ingredients), min_select, max_select, sort_order", "Groupes de personnalisation"],
                ["menu_options", "group_id, name, price_cents, is_default, allow_extra, is_available, sort_order", "Options d'un groupe"],
                ["client_addresses", "client_id, label, address_line, latitude, longitude, is_default", "Adresses de livraison"],
                ["driver_profiles", "vehicle_type, license_plate, is_online, is_approved, current_latitude, current_longitude", "Profil et position du livreur"],
                ["driver_locations_history", "driver_id, latitude, longitude, horodatage", "Historique des positions"],
                ["orders", "client_id, restaurant_id, driver_id, delivery_address_id, status, subtotal_cents, delivery_fee_cents, total_cents, notes, horodatages", "Commandes"],
                ["order_items", "order_id, menu_item_id, quantity, unit_price_cents, notes", "Lignes de commande"],
                ["order_item_options", "order_item_id, group_name, option_name, mode (add / extra / remove), price_cents", "Choix figés au moment de la commande"],
                ["order_status_history", "order_id, status, changed_by, changed_at", "Frise de suivi"],
                ["reviews", "—", "Prévue pour les avis (non exploitée)"]],
               [0.21, 0.52, 0.27]))
S.append(h2("Fonctions et migrations"))
S.append(table([["Élément", "Description"],
                ["place_order()", "Crée la commande, recalcule chaque prix (offres, options), vérifie les règles et l'adresse, enregistre l'historique — tout ou rien."],
                ["get_order_driver()", "Renvoie nom, téléphone, véhicule et position du livreur au seul client de la commande, pendant la livraison."],
                ["auth_role()", "Rôle de l'utilisateur courant, utilisé par les politiques RLS."],
                ["2026-11-15_meal_customization_tnd", "Tables d'options, passage en millimes TND, politiques de l'historique de statuts."],
                ["2026-11-15_order_driver_contact", "Fonction get_order_driver."],
                ["2026-11-15_menu_offers", "Colonnes de promotion sur menu_items."],
                ["2026-11-15_seed_* (Tozeur, Amigo)", "Menus de démonstration : 30 et 42 plats avec photos, options et offres."],
                ["2026-11-16_place_order_function", "Fonction de commande sécurisée pour l'application mobile."]],
               [0.36, 0.64]))

# ======================= 9. Charte graphique =======================
S += h1("Charte graphique")
S.append(h2("Logo"))
logo_img = Image(LOGO, width=70 * mm, height=70 * mm * 231 / 471); logo_img.hAlign = "LEFT"
S.append(logo_img)
S.append(P("Logotype « Foodivo » noir et orange avec virgule orange. Fichier : <i>web/public/foodivo-logo.png</i> (471 × 231 px), "
           "repris dans l'application mobile. Icône d'onglet : « F » italique noir et trait orange (<i>web/app/icon.svg</i>)."))
S.append(h2("Couleurs"))
S.append(swatches())
S.append(h2("Typographie et composants"))
S += bullets([
    "Police système sans empattement (Segoe UI / Roboto / San Francisco) ; titres en graisse extra-bold.",
    "Coins très arrondis (16 à 28 px), ombres douces, dégradés orange → rose pour les éléments principaux.",
    "Boutons principaux en dégradé orange avec halo ; boutons secondaires blancs bordés.",
    "Promotions : badge rond incliné « -20 % », ruban d'angle, prix barré, halo rose / ambre pulsé, compte à rebours rouge sous 24 h.",
    "Statuts colorés : ambre (en attente), bleu (acceptée), indigo (prête / assignée), violet (récupérée), vert (livrée), rouge (refusée).",
])
S.append(h2("Animations"))
S.append(table([["Effet", "Utilisation"],
                ["Apparition en cascade", "Listes de restaurants, plats, commandes"],
                ["Soulèvement au survol / pression", "Cartes et boutons"],
                ["Pop / rebond", "Badge du panier, coche d'option, quantité"],
                ["Secousse", "Choix obligatoire oublié"],
                ["Halo pulsé et reflet", "Cartes et bannière d'offres"],
                ["Point « en direct »", "Restaurant ouvert, commande en cours"]],
               [0.35, 0.65]))

# ======================= 10. Mobile =======================
S += h1("Application mobile Android")
S.append(P("Application Flutter native connectée directement à Supabase (mêmes comptes, menus, photos, promotions et traductions "
           "que le site). Identifiant : <b>com.foodivo.app</b>. Le calcul du prix est délégué à la fonction <i>place_order</i>."))
S.append(table([["Phase", "Contenu", "État"],
                ["1 — Client", "Connexion / inscription, profil, accueil et bons plans, menu et offres spéciales, personnalisation, panier, commande, suivi en direct, appel du livreur, paramètres, FR / EN", status("wip")],
                ["2 — Livreur", "Courses disponibles, acceptation, GPS en arrière-plan, notifications push", status(False)],
                ["3 — Restaurant", "Commandes entrantes avec alerte sonore, acceptation / prête, édition du menu et des offres", status(False)],
                ["4 — Publication", "Icône et écran de démarrage, signature, fiche Google Play, politique de confidentialité", status(False)]],
               [0.17, 0.66, 0.17]))
S.append(note("Phase 1 : code terminé et analysé sans erreur ; en attente d'exécution de la migration <i>place_order</i> et de tests sur émulateur ou téléphone.", "État au " + DATE))

# ======================= 11. Planning =======================
S += h1("Planning et jalons")
S.append(table([["Jalon", "Contenu", "Échéance", "État"],
                ["J1", "Site web : rôles, menus, commandes, suivi temps réel", "15/11/2026", status(True)],
                ["J2", "Personnalisation des plats, devise TND", "15/11/2026", status(True)],
                ["J3", "Design animé, bilingue FR / EN", "15/11/2026", status(True)],
                ["J4", "Contact livreur, promotions, menus de démonstration, identité Foodivo", "15/11/2026", status(True)],
                ["J5", "Application Android — phase 1 client", "[À compléter]", status("wip")],
                ["J6", "Mise en ligne du site (hébergement, nom de domaine)", "[À compléter]", status(False)],
                ["J7", "Application — phases 2 et 3, notifications push", "[À compléter]", status(False)],
                ["J8", "Publication Google Play", "[À compléter]", status(False)]],
               [0.08, 0.55, 0.18, 0.19]))

# ======================= 12. Livrables =======================
S += h1("Livrables")
S.append(table([["Livrable", "Format / emplacement"],
                ["Code source du site web", "Dossier web/ (Next.js)"],
                ["Code source de l'application Android", "Dossier mobile/ (Flutter)"],
                ["Scripts de base de données", "Dossier migrations/ (SQL)"],
                ["Fichier d'application", "APK de test puis AAB signé pour Google Play"],
                ["Traductions", "web/lib/i18n/fr.ts et mobile/assets/i18n/fr.json"],
                ["Documentation", "Présent cahier des charges, README, guide d'installation"],
                ["Identité visuelle", "Logo PNG, icône SVG, palette de couleurs"]],
               [0.45, 0.55]))

# ======================= 13. Contraintes & risques =======================
S += h1("Contraintes et risques")
S.append(h2("Contraintes"))
S += bullets([
    "Modifications de la base appliquées manuellement par le porteur du projet via l'éditeur SQL Supabase.",
    "Coordonnées GPS des adresses provisoires tant que le géocodage n'est pas intégré.",
    "Mise en ligne du site nécessaire avant la diffusion publique de l'application.",
    "Compte développeur Google Play (frais uniques) requis pour la publication.",
])
S.append(h2("Risques"))
S.append(table([["Risque", "Impact", "Mesure"],
                ["Modification des prix par un client malveillant", "Élevé", "Recalcul systématique côté serveur (RG-08)"],
                ["Fuite de données personnelles (téléphones)", "Élevé", "RLS ; téléphone du livreur visible seulement pendant la livraison"],
                ["Deux livreurs acceptent la même course", "Moyen", "Mise à jour conditionnelle (driver_id vide)"],
                ["Perte de connexion du livreur", "Moyen", "Reprise automatique du suivi GPS"],
                ["Photos externes indisponibles", "Faible", "Image de remplacement ; possibilité d'importer les photos dans Storage"],
                ["Blocage d'outils par Windows Smart App Control", "Faible", "Tests sur téléphone réel ou exception pour le SDK"]],
               [0.42, 0.13, 0.45]))

# ======================= 14. Recette =======================
S += h1("Critères de recette")
S.append(table([["Scénario", "Résultat attendu"],
                ["Inscription client puis complétion du profil", "Accès au catalogue après saisie du téléphone et d'une adresse"],
                ["Commande d'un plat avec choix obligatoire non rempli", "Ajout refusé, groupe mis en évidence"],
                ["Commande d'un plat en promotion avec suppléments", "Remise appliquée au prix de base uniquement ; total identique web / mobile / serveur"],
                ["Offre arrivée à échéance", "Prix normal affiché et facturé"],
                ["Commande d'un deuxième restaurant", "Demande de confirmation pour vider le panier"],
                ["Acceptation par le restaurant", "Statut mis à jour chez le client sans rechargement"],
                ["Prise en charge par un livreur", "Nom, téléphone et bouton Appeler visibles par le client"],
                ["Livraison terminée", "Coordonnées du livreur masquées, commande « Livrée »"],
                ["Accès à /admin avec un compte client", "Page « Accès refusé »"],
                ["Changement de langue", "Tous les textes et dates passent en français / anglais"]],
               [0.45, 0.55]))
S.append(Spacer(1, 6))
S.append(P("Chaque scénario est validé sur ordinateur, sur téléphone (site responsive) et sur l'application Android.", SMALL))

# ======================= 15. Évolutions =======================
S += h1("Évolutions futures")
S += bullets([
    "<b>Paiement en ligne</b> (carte bancaire, portefeuilles tunisiens) et paiement à la livraison explicite.",
    "<b>Notifications push</b> (Firebase Cloud Messaging) pour clients, restaurants et livreurs.",
    "<b>Géocodage</b> des adresses et calcul des frais de livraison selon la distance.",
    "<b>Carte intégrée</b> avec trajet du livreur en direct.",
    "<b>Avis et notes</b> sur les restaurants et les livreurs (table <i>reviews</i>).",
    "<b>Codes promo</b> et programme de fidélité.",
    "<b>Application iOS</b> à partir du même code Flutter.",
    "<b>Statistiques avancées</b> pour les restaurants (plats les plus vendus, heures de pointe).",
])

# ======================= Validation =======================
S.append(PageBreak())
S += h1("Validation du document")
S.append(P("Le présent cahier des charges est validé par les parties ci-dessous. Toute modification ultérieure fera l'objet d'une nouvelle version."))
sig = Table([[Paragraph("<b>Porteur du projet</b>", CELL_B), Paragraph("<b>Équipe technique</b>", CELL_B), Paragraph("<b>Encadrant / Client</b>", CELL_B)],
             [Paragraph("Nom : ____________________<br/><br/>Date : ____ / ____ / ________<br/><br/>Signature :<br/><br/><br/><br/>", CELL)] * 3],
            colWidths=[W / 3] * 3)
sig.setStyle(TableStyle([("GRID", (0, 0), (-1, -1), 0.6, S200), ("BACKGROUND", (0, 0), (-1, 0), BRAND50),
                         ("TOPPADDING", (0, 0), (-1, -1), 8), ("LEFTPADDING", (0, 0), (-1, -1), 8), ("VALIGN", (0, 0), (-1, -1), "TOP")]))
S.append(sig)

doc.multiBuild(S)
print("OK", OUT)
