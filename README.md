# Sistema Ecléctico de Trading Algorítmico y Evolución Multi-Agente LLM

## 1. Declaración de Propósito
Este sistema ejecuta un análisis multidimensional cruzado sobre el activo subyacente Bitcoin (BTC) con el objetivo de proyectar vectores de precio y tiempo para las próximas 72 horas, segmentados en ventanas temporales discretas de 24, 48 y 72 horas. 

## 2. Enfoques Analíticos Obligatorios
Cada ciclo iterativo exige la convergencia y contraste de tres metodologías independientes:
* **Enfoque Institucional:** Análisis fundamental, order blocks, liquidez institucional (SMC) y proyecciones de escenarios de precio/tiempo basados en flujos de órdenes de alta frecuencia.
* **Modelo Estadístico:** Modelado formal de datos numéricos aplicando rigurosamente al menos un marco estadístico (ej. autoregresión, medias móviles integradas, etc.).
* **Modelo Probabilístico:** Evaluación de densidad de probabilidad y distribución de frecuencias aplicando modelos estocásticos dirigidos (ej. Cadenas de Markov, simulaciones Monte Carlo).

## 3. Arquitectura Concurrente y Red Neuronal de Archivos
El núcleo operativo funciona como una competencia determinista entre múltiples Agentes de Inteligencia Artificial y Modelos de Lenguaje de Gran Escala (LLMs).
* **Mitigación de Estocasticidad:** Se prohíbe explícitamente la confabulación, alucinación y falseo de métricas. Todo cálculo numérico debe ser verificado localmente mediante herramientas de programación.
* **Memoria Evolutiva:** La carpeta database/neurons/ actúa como una red de memoria cronológica. Cada "neurona" (carpeta indexada) representa un estado de conocimiento que sirve como entrada (input) inmutable para el análisis de la iteración subsiguiente.

## 4. Estructura del Repositorio
* /prompts: Contratos modulares de instrucciones y restricciones absolutas.
* /database/neurons: Historial cronológico evolutivo del sistema (YYYY-MM-DD_neuron-XXX).
