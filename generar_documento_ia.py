# -*- coding: utf-8 -*-
"""
Script para generar el documento PDF "Uso_de_Inteligencia_Artificial.pdf"
con un diseño visual altamente profesional y contenido detallado.
"""
import os
import sys
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    """
    Canvas personalizado para realizar una numeración de páginas dinámica
    y dibujar encabezados/pies de página en dos pasadas.
    """
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_decorations(self, page_count):
        # No dibujar en la portada (Página 1)
        if self._pageNumber == 1:
            return

        self.saveState()
        
        # Colores
        text_color = colors.HexColor("#4A5568")
        line_color = colors.HexColor("#CBD5E1")
        navy_color = colors.HexColor("#1A365D")
        
        # --- Encabezado ---
        self.setFont("Helvetica", 8)
        self.setFillColor(text_color)
        self.drawString(54, 750, "INFORME TÉCNICO: INTEGRACIÓN DE IA EN EL FLUJO DE TRABAJO")
        self.drawRightString(558, 750, "PROYECTO: BATALLAS POKÉMON EN ELIXIR")
        
        self.setStrokeColor(line_color)
        self.setLineWidth(0.5)
        self.line(54, 742, 558, 742)
        
        # --- Pie de Página ---
        page_text = f"Página {self._pageNumber} de {page_count}"
        self.drawRightString(558, 45, page_text)
        self.drawString(54, 45, "Desarrollo Colaborativo y Agentes Inteligentes © 2026")
        self.line(54, 58, 558, 58)
        
        self.restoreState()

def crear_pdf(nombre_archivo):
    # Configuración del documento
    # Margen izquierdo/derecho: 54 pt (0.75 in), Margen superior: 70 pt, Margen inferior: 70 pt
    doc = SimpleDocTemplate(
        nombre_archivo,
        pagesize=letter,
        leftMargin=54,
        rightMargin=54,
        topMargin=72,
        bottomMargin=72
    )
    
    # Paleta de colores premium
    PRIMARY_COLOR = colors.HexColor("#1A365D")   # Azul Marino Oscuro
    SECONDARY_COLOR = colors.HexColor("#4A5568") # Gris pizarra
    ACCENT_COLOR = colors.HexColor("#D69E2E")    # Dorado sutil
    BG_LIGHT = colors.HexColor("#F7FAFC")        # Fondo claro
    BORDER_COLOR = colors.HexColor("#E2E8F0")    # Bordes grises
    TEXT_COLOR = colors.HexColor("#2D3748")      # Texto oscuro
    
    # Estilos
    styles = getSampleStyleSheet()
    
    # Modificar estilos existentes de forma segura o añadir nuevos con nombres únicos
    title_style = ParagraphStyle(
        'CoverTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=26,
        leading=32,
        textColor=PRIMARY_COLOR,
        alignment=1, # Centrado
        spaceAfter=15
    )
    
    subtitle_style = ParagraphStyle(
        'CoverSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=14,
        leading=18,
        textColor=SECONDARY_COLOR,
        alignment=1,
        spaceAfter=40
    )
    
    meta_label_style = ParagraphStyle(
        'CoverMetaLabel',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=10,
        leading=14,
        textColor=PRIMARY_COLOR
    )
    
    meta_val_style = ParagraphStyle(
        'CoverMetaVal',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=10,
        leading=14,
        textColor=TEXT_COLOR
    )

    h1_style = ParagraphStyle(
        'Header1_Custom',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=18,
        leading=22,
        textColor=PRIMARY_COLOR,
        spaceBefore=15,
        spaceAfter=10,
        keepWithNext=True
    )
    
    h2_style = ParagraphStyle(
        'Header2_Custom',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=12,
        leading=16,
        textColor=SECONDARY_COLOR,
        spaceBefore=12,
        spaceAfter=6,
        keepWithNext=True
    )
    
    body_style = ParagraphStyle(
        'Body_Custom',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=10,
        leading=15,
        textColor=TEXT_COLOR,
        spaceAfter=10
    )
    
    bullet_style = ParagraphStyle(
        'Bullet_Custom',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=10,
        leading=14,
        textColor=TEXT_COLOR,
        leftIndent=20,
        firstLineIndent=-10,
        spaceAfter=6
    )
    
    callout_style = ParagraphStyle(
        'Callout_Custom',
        parent=styles['Normal'],
        fontName='Helvetica-Oblique',
        fontSize=9.5,
        leading=14.5,
        textColor=PRIMARY_COLOR
    )
    
    table_hdr_style = ParagraphStyle(
        'TableHdr',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=9,
        leading=12,
        textColor=colors.white
    )
    
    table_body_style = ParagraphStyle(
        'TableBody',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=11,
        textColor=TEXT_COLOR
    )

    story = []
    
    # =========================================================================
    # PORTADA (Página 1)
    # =========================================================================
    story.append(Spacer(1, 40))
    
    # Barra decorativa superior (Dorado)
    decor_top = Table([[""]], colWidths=[504], rowHeights=[6])
    decor_top.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), ACCENT_COLOR),
        ('BOTTOMPADDING', (0,0), (-1,-1), 0),
        ('TOPPADDING', (0,0), (-1,-1), 0),
    ]))
    story.append(decor_top)
    story.append(Spacer(1, 60))
    
    # Título Principal
    story.append(Paragraph("INFORME DE INGENIERÍA DE SOFTWARE:<br/>USO DE INTELIGENCIA ARTIFICIAL EN EL FLUJO DE TRABAJO", title_style))
    story.append(Spacer(1, 10))
    
    # Subtítulo
    story.append(Paragraph("Integración de Temporizadores en Salas de Intercambio y Concurrencia Distribuida<br/>en el Proyecto Final de Batallas Pokémon (Elixir & OTP)", subtitle_style))
    story.append(Spacer(1, 50))
    
    # Detalles decorativos del centro
    center_line = Table([[""]], colWidths=[100], rowHeights=[2])
    center_line.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), PRIMARY_COLOR),
        ('BOTTOMPADDING', (0,0), (-1,-1), 0),
        ('TOPPADDING', (0,0), (-1,-1), 0),
    ]))
    story.append(center_line)
    story.append(Spacer(1, 80))
    
    # Bloque de metadatos en tabla para perfecta alineación
    metadata_data = [
        [Paragraph("Preparado para:", meta_label_style), Paragraph("Evaluación de Proyecto Final", meta_val_style)],
        [Paragraph("Asistente de Desarrollo:", meta_label_style), Paragraph("Antigravity AI (Google DeepMind Team)", meta_val_style)],
        [Paragraph("Flujo de Trabajo:", meta_label_style), Paragraph("Pair Programming / Agentes Autónomos / CLI", meta_val_style)],
        [Paragraph("Tecnologías Centrales:", meta_label_style), Paragraph("Elixir, OTP, GenServer, Python, ReportLab", meta_val_style)],
        [Paragraph("Fecha de Entrega:", meta_label_style), Paragraph("20 de Mayo de 2026", meta_val_style)],
    ]
    
    metadata_table = Table(metadata_data, colWidths=[150, 354])
    metadata_table.setStyle(TableStyle([
        ('LINEBELOW', (0,0), (-1,-1), 0.5, BORDER_COLOR),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(metadata_table)
    
    story.append(Spacer(1, 40))
    # Barra decorativa inferior (Azul Marino)
    decor_bottom = Table([[""]], colWidths=[504], rowHeights=[4])
    decor_bottom.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), PRIMARY_COLOR),
        ('BOTTOMPADDING', (0,0), (-1,-1), 0),
        ('TOPPADDING', (0,0), (-1,-1), 0),
    ]))
    story.append(decor_bottom)
    
    story.append(PageBreak())
    
    # =========================================================================
    # SECCIÓN 1: INTRODUCCIÓN (Página 2)
    # =========================================================================
    story.append(Paragraph("1. INTRODUCCIÓN", h1_style))
    story.append(Paragraph(
        "El desarrollo moderno de software exige no solo robustez lógica y escalabilidad arquitectónica, sino también agilidad en el ciclo de vida del código. En este contexto, la incorporación de herramientas de Inteligencia Artificial (IA) generativa se ha convertido en una pieza fundamental para acelerar procesos complejos de diseño, refactorización y aseguramiento de calidad.",
        body_style
    ))
    story.append(Paragraph(
        "El presente informe técnico expone la metodología bajo la cual se empleó la Inteligencia Artificial de forma integrada en el desarrollo del proyecto final <b>Plataforma de Batallas Pokémon</b> en Elixir. Específicamente, se detalla cómo las tecnologías basadas en agentes autónomos, asistentes conversacionales y herramientas de automatización CLI colaboraron con el desarrollador humano para estructurar un clúster concurrente distribuido de red, e implementar un sistema dinámico de temporizadores (timeouts) en la sala de intercambios de Pokémon, garantizando la consistencia y liberación adecuada de memoria en los procesos del GenServer.",
        body_style
    ))
    
    # GitHub-Style Alert / Callout
    callout_intro = [
        [Paragraph("<b>Nota de Arquitectura:</b> El software resultante aprovecha la robustez de los procesos concurrentes de Elixir supervisados por un DynamicSupervisor, regulados dinámicamente por temporizadores nativos de la máquina virtual de Erlang (BEAM). La IA actuó como un copiloto experto facilitando la modelación y la lógica exacta de control de sincronía.", callout_style)]
    ]
    t_callout_intro = Table(callout_intro, colWidths=[504])
    t_callout_intro.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), BG_LIGHT),
        ('BOX', (0,0), (-1,-1), 1, BORDER_COLOR),
        ('LINELEFT', (0,0), (0,-1), 4, PRIMARY_COLOR),
        ('TOPPADDING', (0,0), (-1,-1), 10),
        ('BOTTOMPADDING', (0,0), (-1,-1), 10),
        ('LEFTPADDING', (0,0), (-1,-1), 15),
        ('RIGHTPADDING', (0,0), (-1,-1), 15),
    ]))
    story.append(t_callout_intro)
    story.append(Spacer(1, 15))
    
    # =========================================================================
    # SECCIÓN 2: HERRAMIENTAS DE IA EMPLEADAS
    # =========================================================================
    story.append(Paragraph("2. HERRAMIENTAS DE IA EMPLEADAS", h1_style))
    story.append(Paragraph(
        "Para lograr un flujo de desarrollo eficiente, se implementó una aproximación multi-herramienta, utilizando diferentes interfaces de IA según el nivel de abstracción y el tipo de tarea requerida:",
        body_style
    ))
    
    story.append(Paragraph(
        "<b>A. Agentes Inteligentes Autónomos (Antigravity):</b> Esta representa la herramienta de mayor nivel de integración en el flujo de trabajo. Al tener capacidades directas de lectura/escritura del sistema de archivos, ejecución controlada de terminal CLI en sandboxes, y análisis exhaustivo de dependencias, el agente operó de forma autónoma. Fue capaz de:",
        body_style
    ))
    story.append(Paragraph("• Analizar y mapear el codebase completo del proyecto mediante comandos de búsqueda indexada (como ripgrep) y listados de directorios.", bullet_style))
    story.append(Paragraph("• Proponer de forma autónoma planos técnicos de implementación integrales (<i>implementation plans</i>) antes de modificar código crítico.", bullet_style))
    story.append(Paragraph("• Modificar con precisión quirúrgica archivos individuales mediante reemplazos selectivos de bloques de código en los GenServers concurrentes sin alterar otras funcionalidades.", bullet_style))
    
    story.append(Paragraph(
        "<b>B. Chatbots y Modelos de Lenguaje Avanzados (Claude & Gemini):</b> Utilizados para resolver problemas de diseño de alto nivel. A través de la conversación, se debatieron las alternativas de diseño de la sincronización distribuida, comparando el enfoque original del profesor con los requerimientos específicos del proyecto. Estos modelos ayudaron a concebir el modelo de doble temporizador en GenServers interactivos.",
        body_style
    ))
    
    story.append(Paragraph(
        "<b>C. Interfaces de Línea de Comandos (CLI) Inteligentes:</b> Utilizadas para la monitorización de ejecuciones asíncronas de fondo (como la instalación automatizada de dependencias como reportlab) y la orquestación de tareas complejas en la terminal de Windows sin requerir la intervención constante del usuario.",
        body_style
    ))
    
    story.append(PageBreak())
    
    # =========================================================================
    # SECCIÓN 3: INTEGRACIÓN EN EL FLUJO DE TRABAJO (Página 3)
    # =========================================================================
    story.append(Paragraph("3. INTEGRACIÓN EN EL FLUJO DE TRABAJO (WORKFLOW)", h1_style))
    story.append(Paragraph(
        "La integración de las herramientas de IA no fue un proceso caótico de 'copiar y pegar' código, sino que se rigió bajo un ciclo de vida estructurado e iterativo de 4 fases principales. Esto garantizó que el sistema mantuviera su estabilidad en todo momento:",
        body_style
    ))
    
    # Tabla del Flujo de Trabajo
    workflow_data = [
        [
            Paragraph("Fase", table_hdr_style),
            Paragraph("Descripción del Flujo Colaborativo", table_hdr_style),
            Paragraph("Rol de la IA", table_hdr_style),
            Paragraph("Rol del Humano", table_hdr_style)
        ],
        [
            Paragraph("<b>1. Investigación</b>", table_body_style),
            Paragraph("Lectura analítica de las especificaciones del proyecto y del código previo suministrado por el profesor (servidores base, GenServers distribuidos).", table_body_style),
            Paragraph("Localización semántica y mapeo del codebase. Explicación de dependencias y lógica de flujos concurrentes.", table_body_style),
            Paragraph("Establecer los requerimientos pedagógicos y proveer el contexto general del servidor original.", table_body_style)
        ],
        [
            Paragraph("<b>2. Planificación</b>", table_body_style),
            Paragraph("Generación de una propuesta de diseño técnico documentada (<i>implementation_plan.md</i>) detallando los archivos a alterar e impactos arquitectónicos.", table_body_style),
            Paragraph("Estructurar y documentar el plan de implementación detallando las estrategias de temporizadores y red distribuida.", table_body_style),
            Paragraph("Revisar el plan técnico propuesto, solicitar correcciones (ej. evitar crear carpetas nuevas e integrar todo al servidor actual) y otorgar aprobación formal.", table_body_style)
        ],
        [
            Paragraph("<b>3. Ejecución</b>", table_body_style),
            Paragraph("Programación concurrente y refactorización modular. Automatización de tareas de soporte (ej. script de PDF con reportlab).", table_body_style),
            Paragraph("Reemplazar código en caliente en el proyecto Elixir. Escribir scripts auxiliares en Python y dar formato estético.", table_body_style),
            Paragraph("Monitorear el avance visual y de consola, interactuando con los comandos despachados.", table_body_style)
        ],
        [
            Paragraph("<b>4. Verificación</b>", table_body_style),
            Paragraph("Ejecución del clúster interactivo de Elixir (<i>iex</i>), validación de mensajería asíncrona distribuda y compilación del informe final PDF.", table_body_style),
            Paragraph("Identificar lints o advertencias, simular temporizadores de inactividad, y ejecutar el motor ReportLab para la compilación visual.", table_body_style),
            Paragraph("Verificar el comportamiento de desconexión en consola y abrir el documento PDF generado para validar la calidad de entrega.", table_body_style)
        ]
    ]
    
    t_workflow = Table(workflow_data, colWidths=[80, 180, 124, 120])
    t_workflow.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), PRIMARY_COLOR),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('GRID', (0,0), (-1,-1), 0.5, BORDER_COLOR),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, BG_LIGHT]),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(t_workflow)
    story.append(Spacer(1, 15))
    
    # =========================================================================
    # SECCIÓN 4: DETALLE TÉCNICO DE LA IMPLEMENTACIÓN
    # =========================================================================
    story.append(Paragraph("4. CASO DE ESTUDIO: TEMPORIZADORES EN LA SALA DE INTERCAMBIO", h1_style))
    story.append(Paragraph(
        "El mayor reto técnico residió en implementar un control dinámico de temporizadores dentro de un GenServer interactivo que maneja estados transicionales compartidos entre dos usuarios distribuidos. Mediante la colaboración con la IA, se concibió un sistema robusto de <b>Doble Timeout</b>:",
        body_style
    ))
    
    story.append(Paragraph(
        "<b>1. Temporizador de Creación de Sala (60 segundos):</b> Al ser creada una sala por un entrenador (ej. ejecutando <code>crear_sala_intercambio</code>), el GenServer inicia un temporizador mediante <code>Process.send_after/3</code>. Si en los siguientes 60 segundos ningún rival se une mediante <code>unirse_sala_intercambio</code>, el proceso recibe el mensaje asíncrono <code>:timeout_creacion</code>, limpia de forma segura el registro en la tabla ETS de clúster global y se detiene limpiamente con <code>{:stop, :normal, estado}</code>, liberando la memoria del BEAM.",
        body_style
    ))
    
    story.append(Paragraph(
        "<b>2. Temporizador de Negociación Activa (120 segundos):</b> Una vez que un entrenador invitado se une, la sala transiciona a una fase activa. El sistema cancela inmediatamente el temporizador de creación original mediante <code>Process.cancel_timer/1</code> para evitar interrupciones no deseadas, e inicia un segundo temporizador de 120 segundos. Esto asegura que si los participantes abren una sala de negociación activa pero la abandonan o no concretan sus ofertas Pokémon, la sala no permanezca abierta infinitamente. Al expirar, el GenServer gatilla <code>:timeout_activo</code>, notifica la expiración y se auto-destruye limpiamente.",
        body_style
    ))
    
    story.append(Paragraph(
        "<b>3. Cancelación Segura por Intercambio Completo:</b> Si ambos entrenadores logran concretar el intercambio (ofrecer pokémon y confirmar), el sistema cancela activamente cualquier temporizador programado antes de proceder con el guardado de persistencia JSON y el cierre del proceso. Esto previene condiciones de carrera o mensajes basura que pudiesen afectar a otros GenServers.",
        body_style
    ))
    
    story.append(PageBreak())
    
    # =========================================================================
    # SECCIÓN 5: CONCLUSIONES Y LECCIONES APRENDIDAS (Página 4)
    # =========================================================================
    story.append(Paragraph("5. CONCLUSIONES Y LECCIONES APRENDIDAS", h1_style))
    story.append(Paragraph(
        "El uso estructurado de Inteligencia Artificial en el desarrollo de la <b>Plataforma de Batallas Pokémon</b> en Elixir proporcionó valiosos aprendizajes metodológicos y de ingeniería de software:",
        body_style
    ))
    
    story.append(Paragraph(
        "<b>Aumento Sustancial en la Productividad:</b> La IA redujo drásticamente el tiempo empleado en tareas operativas repetitivas (como la escritura de esqueletos GenServer estandarizados, persistencia JSON y formateo visual de reportes). Esto permitió al desarrollador centrarse por completo en refinar la lógica distributiva y los mecanismos de sincronización de red.",
        body_style
    ))
    
    story.append(Paragraph(
        "<b>Robustez del Código mediante Diseño Riguroso:</b> El proceso de forzar la generación de un <i>Plan de Implementación</i> detallado antes de escribir cualquier línea de código previno fallos arquitectónicos graves. Por ejemplo, se detectó de forma prematura que crear una carpeta de servidor externa (como se propuso inicialmente) dificultaría la integración con el ecosistema ETS y Supervisor del clúster principal, decidiendo unificar todo bajo el mismo clúster distributed.",
        body_style
    ))
    
    story.append(Paragraph(
        "<b>Sinergia Humano-Máquina:</b> Las herramientas de IA no sustituyen el criterio de ingeniería del desarrollador humano. El programador actuó en todo momento como el tomador de decisiones estratégicas, validando, refinando las propuestas de temporizadores y testeando físicamente las fallas de red en Windows, mientras que la IA aportó velocidad de síntesis, precisión técnica y control de dependencias.",
        body_style
    ))
    
    story.append(Spacer(1, 10))
    
    # GitHub Alert/Callout Final
    callout_final = [
        [Paragraph("<b>Conclusión Central:</b> La combinación de la arquitectura orientada a procesos y tolerancia a fallos de Elixir (OTP) junto con el flujo ordenado y automatizado de la Inteligencia Artificial dio como resultado un sistema escalable, libre de bloqueos inactivos y con un estándar estético e institucional sobresaliente.", callout_style)]
    ]
    t_callout_final = Table(callout_final, colWidths=[504])
    t_callout_final.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), BG_LIGHT),
        ('BOX', (0,0), (-1,-1), 1, BORDER_COLOR),
        ('LINELEFT', (0,0), (0,-1), 4, ACCENT_COLOR),
        ('TOPPADDING', (0,0), (-1,-1), 10),
        ('BOTTOMPADDING', (0,0), (-1,-1), 10),
        ('LEFTPADDING', (0,0), (-1,-1), 15),
        ('RIGHTPADDING', (0,0), (-1,-1), 15),
    ]))
    story.append(t_callout_final)
    story.append(Spacer(1, 40))
    
    # Firma y Cierre del Documento
    firma_data = [
        [Paragraph("<b>Desarrollado y Compilado por:</b>", meta_label_style), Paragraph("<b>Aprobado por:</b>", meta_label_style)],
        [Paragraph("Antigravity Coding Assistant<br/>Google DeepMind Team", meta_val_style), Paragraph("Ing. del Proyecto / Profesor de Cátedra<br/>Plataforma de Batallas Pokémon", meta_val_style)]
    ]
    t_firma = Table(firma_data, colWidths=[252, 252])
    t_firma.setStyle(TableStyle([
        ('LINEABOVE', (0,0), (-1,0), 0.5, BORDER_COLOR),
        ('TOPPADDING', (0,0), (-1,-1), 10),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
    ]))
    story.append(t_firma)
    
    # Construcción final del documento utilizando NumberedCanvas
    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"[ÉXITO] Documento PDF '{nombre_archivo}' generado exitosamente.")

if __name__ == "__main__":
    nombre_defecto = "Uso_de_Inteligencia_Artificial.pdf"
    if len(sys.argv) > 1:
        nombre_defecto = sys.argv[1]
    
    crear_pdf(nombre_defecto)
